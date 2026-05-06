#!/usr/bin/env bash
# scripts/validate-spec.sh
#
# Pre-dispatch + pre-commit verification for peptide-website task specs.
# Enforces SPEC_LESSONS L-002 + L-003: every citation in a spec must be
# grep-verifiable against the actual peptide-website checkout at the spec's
# anchor SHA. Specs that fail verification cannot be dispatched (or, with the
# pre-commit hook installed, cannot even be committed).
#
# Usage:
#   scripts/validate-spec.sh <spec-path> [<spec-path> ...]
#   scripts/validate-spec.sh peptide-mvp/specs/W0/F49-secret-scanning-precommit.md
#
# Env:
#   PEPTIDE_REPO    Path to peptide-website checkout (default: /home/user/peptide-website)
#   ANCHOR_SHA      SHA to verify against (default: read from spec or use HEAD)
#
# Exit codes:
#   0  — all specs pass
#   1  — at least one spec fails (details printed to stderr)
#   2  — usage error
#   3  — peptide-website checkout not accessible

set -uo pipefail

PEPTIDE_REPO="${PEPTIDE_REPO:-/home/user/peptide-website}"
DEFAULT_ANCHOR="486f63b"

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <spec-path> [<spec-path> ...]" >&2
  exit 2
fi

# Check checkout accessibility before anything else
if [ ! -d "$PEPTIDE_REPO/.git" ]; then
  echo "[validate-spec] FATAL: peptide-website checkout not at $PEPTIDE_REPO" >&2
  echo "[validate-spec] Set PEPTIDE_REPO env var or clone Layne512/peptide-website to $PEPTIDE_REPO" >&2
  echo "[validate-spec] Per CLAUDE.md hard rule 9, specs without grep-verifiable citations cannot live under peptide-mvp/specs/W*/" >&2
  exit 3
fi

GIT="git -C $PEPTIDE_REPO"
TOTAL_FAIL=0

validate_one() {
  local spec="$1"
  local fail=0
  local anchor="$DEFAULT_ANCHOR"

  if [ ! -f "$spec" ]; then
    echo "[validate-spec] $spec: FILE NOT FOUND" >&2
    return 1
  fi

  # 1. Forbidden markers (L-003)
  if grep -qE '# *unverified|⚠ *unverified|grep before dispatch' "$spec"; then
    echo "[validate-spec] $spec: FAIL — contains forbidden 'unverified' / 'grep before dispatch' marker (L-003 retired this pattern; move to peptide-mvp/specs/drafts/)" >&2
    fail=1
  fi

  # 2. Anchor SHA (read from spec frontmatter if present)
  local spec_anchor
  spec_anchor=$(awk '/^anchor:/ {print $2; exit}' "$spec" 2>/dev/null | tr -d '"' || true)
  if [ -n "$spec_anchor" ]; then
    anchor="$spec_anchor"
  fi

  # Verify anchor exists in target repo
  if ! $GIT cat-file -e "${anchor}^{commit}" 2>/dev/null; then
    echo "[validate-spec] $spec: FAIL — anchor SHA $anchor does not exist in $PEPTIDE_REPO" >&2
    fail=1
    return $fail
  fi

  # 3. must_read_before_writing entries — every listed path must exist at anchor
  #    (skip entries that are doc paths under peptide-mvp/ — those live in this repo)
  local in_must_read=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^must_read_before_writing: ]]; then
      in_must_read=1
      continue
    fi
    if [ "$in_must_read" = 1 ]; then
      # YAML list item, possibly with comment
      if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
        local entry="${BASH_REMATCH[1]}"
        # Strip inline comment + whitespace
        entry="$(echo "$entry" | sed 's/[[:space:]]*#.*$//' | xargs)"
        # Skip peptide-mvp paths (live in Orchestrator_Test, not peptide-website)
        if [[ "$entry" == peptide-mvp/* ]]; then continue; fi
        # Skip empty / wildcard-only entries (just check parent dir exists)
        local check_path="$entry"
        if [[ "$entry" == */ ]]; then
          check_path="${entry%/}"
        fi
        if ! $GIT cat-file -e "${anchor}:${check_path}" 2>/dev/null; then
          # Try as directory listing
          if ! $GIT ls-tree -r --name-only "$anchor" -- "$check_path" 2>/dev/null | head -1 | grep -q .; then
            echo "[validate-spec] $spec: FAIL — must_read entry '$entry' not found at $anchor" >&2
            fail=1
          fi
        fi
      elif [[ "$line" =~ ^[a-z_]+: ]] || [[ "$line" =~ ^---$ ]]; then
        # Next YAML key or end of frontmatter
        in_must_read=0
      fi
    fi
  done < "$spec"

  # 4. Code-block import paths — every "from '@/..." path must resolve
  #    @/ maps to repo root in Next.js convention; we check both as-is and with .ts/.tsx
  local imports
  imports=$(grep -oE "from ['\"]@/[a-zA-Z0-9/_.-]+['\"]" "$spec" | sed -E "s/from ['\"]@\///; s/['\"]//" | sort -u)
  while IFS= read -r imp; do
    [ -z "$imp" ] && continue
    local found=0
    for ext in "" ".ts" ".tsx" "/index.ts" "/index.tsx"; do
      if $GIT cat-file -e "${anchor}:${imp}${ext}" 2>/dev/null; then
        found=1
        break
      fi
    done
    if [ "$found" = 0 ]; then
      echo "[validate-spec] $spec: FAIL — import path '@/$imp' does not resolve at $anchor" >&2
      fail=1
    fi
  done <<< "$imports"

  # 5. files_owned entries — must either exist at anchor OR the spec must
  #    explicitly state "CREATED by this task" (which the spec author must annotate)
  local in_files_owned=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^files_owned: ]]; then
      in_files_owned=1
      continue
    fi
    if [ "$in_files_owned" = 1 ]; then
      if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
        local entry="${BASH_REMATCH[1]}"
        local has_created_marker=0
        if [[ "$entry" =~ "CREATED" ]] || [[ "$entry" =~ "(NEW)" ]] || [[ "$entry" =~ "created by this task" ]]; then
          has_created_marker=1
        fi
        entry="$(echo "$entry" | sed 's/[[:space:]]*#.*$//' | xargs)"
        if [ "$has_created_marker" = 0 ] && ! $GIT cat-file -e "${anchor}:${entry}" 2>/dev/null; then
          # files_owned can include to-be-created files, but they MUST be marked
          echo "[validate-spec] $spec: WARN — files_owned entry '$entry' not at $anchor and missing 'CREATED' / '(NEW)' marker" >&2
          # WARN, not FAIL — files_owned legitimately includes new files for some tasks
        fi
      elif [[ "$line" =~ ^[a-z_]+: ]] || [[ "$line" =~ ^---$ ]]; then
        in_files_owned=0
      fi
    fi
  done < "$spec"

  if [ "$fail" = 0 ]; then
    echo "[validate-spec] $spec: OK"
  fi
  return $fail
}

for spec in "$@"; do
  validate_one "$spec" || TOTAL_FAIL=$((TOTAL_FAIL + 1))
done

if [ "$TOTAL_FAIL" -gt 0 ]; then
  echo "[validate-spec] $TOTAL_FAIL spec(s) FAILED validation" >&2
  exit 1
fi

exit 0
