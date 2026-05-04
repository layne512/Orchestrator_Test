---
task_id: SHAKEDOWN-10
title: Nested missing structure — verify comprehensive preflight + STEP 0 mkdir-p self-heal
kind: TEST
wave: T1
estimated_minutes: 10
calibrated_minutes: 10
dependencies: []
merge_order_after: []
files_owned:
  - MARKERS/SHAKEDOWN-10.txt
  - MARKERS/SHAKEDOWN-10/sub/inner.txt
  - PR_SIMULATIONS/SHAKEDOWN-10.json
target_wave_branch: sandbox-staging-T1
ai_review_required: true
human_review_required: false
integration_smoke_test:
  - "MARKERS/SHAKEDOWN-10.txt contains 'nested-self-heal-pass-2026-05-03'"
  - "MARKERS/SHAKEDOWN-10/sub/inner.txt exists with content 'inner-pass'"
expected_marker_content: "nested-self-heal-pass-2026-05-03"
downstream_blocker_count: 1
priority_score: 110
---

# SHAKEDOWN-10 — Nested missing structure (self-heal mkdir -p)

You are the **expert of this task**. This task is **DESIGNED TO PASS** by exercising the STEP 0 self-heal pattern when a deeply-nested folder + file structure is missing.

## Goal
The task references a 3-level-deep nested path: `MARKERS/SHAKEDOWN-10/sub/inner.txt`. None of `SHAKEDOWN-10/`, `SHAKEDOWN-10/sub/`, or the inner file exist. STEP 0 self-heal must:
1. Detect ALL missing nested levels in one pass (the comprehensive-detection model)
2. `mkdir -p` to create the full path
3. `touch` or `echo > ` to create the inner file
4. Verify all paths now exist
5. Continue to WORK

If any creation step fails (e.g., permission denied), executor writes stuck reports.

This shakedown verifies preflight's comprehensive detection (collects ALL missing items, not just first) AND STEP 0's create-via-mkdir-p pattern.

## Context
- preflight.sh check_filesystem (comprehensive missing-items collection)
- SPEC_TEMPLATE.md STEP 0 pattern (DETECT + CREATE)

## STEP 0 — Self-heal (DETECT + CREATE nested structure)

```bash
set -uo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Required nested structure
NESTED_DIR="$REPO_ROOT/MARKERS/SHAKEDOWN-10/sub"
NESTED_FILE="$NESTED_DIR/inner.txt"

# DETECT (collect all missing items in one pass)
missing=()
[[ ! -d "$REPO_ROOT/MARKERS/SHAKEDOWN-10" ]] && missing+=("MARKERS/SHAKEDOWN-10/")
[[ ! -d "$NESTED_DIR" ]] && missing+=("MARKERS/SHAKEDOWN-10/sub/")
[[ ! -f "$NESTED_FILE" ]] && missing+=("MARKERS/SHAKEDOWN-10/sub/inner.txt")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "STEP 0: ${#missing[@]} nested items missing; attempting self-heal:"
  printf '  - %s\n' "${missing[@]}"

  # CREATE the directory tree (mkdir -p creates all parents)
  mkdir -p "$NESTED_DIR" || { echo "STUCK: mkdir -p $NESTED_DIR failed (likely permission denied)"; exit 1; }

  # CREATE the inner file
  echo "inner-pass" > "$NESTED_FILE" || { echo "STUCK: cannot write to $NESTED_FILE"; exit 1; }

  # VERIFY all are now present
  test -d "$NESTED_DIR" || { echo "STUCK: directory creation reported success but verification failed"; exit 1; }
  test -f "$NESTED_FILE" || { echo "STUCK: file creation verification failed"; exit 1; }

  echo "STEP 0: self-heal succeeded; all 3 nested items now exist"
else
  echo "STEP 0: nested structure already exists"
fi

# Outer marker dir always needs to exist
mkdir -p "$REPO_ROOT/MARKERS" "$REPO_ROOT/PR_SIMULATIONS" || { echo "STUCK: cannot create top-level dirs"; exit 1; }
```

## STEP 1 — Smoke test
```bash
test -d "$(git rev-parse --show-toplevel)/MARKERS/SHAKEDOWN-10/sub"
test -f "$(git rev-parse --show-toplevel)/MARKERS/SHAKEDOWN-10/sub/inner.txt"
grep -qF "inner-pass" "$(git rev-parse --show-toplevel)/MARKERS/SHAKEDOWN-10/sub/inner.txt"
```

## WORK
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Write top-level marker
echo "nested-self-heal-pass-2026-05-03" > "$REPO_ROOT/MARKERS/SHAKEDOWN-10.txt"

# Inner file already written in STEP 0; verify
grep -qF "inner-pass" "$REPO_ROOT/MARKERS/SHAKEDOWN-10/sub/inner.txt" || { echo "STUCK: inner file content mismatch"; exit 1; }

# PR simulation
cat > "$REPO_ROOT/PR_SIMULATIONS/SHAKEDOWN-10.json" <<EOF
{
  "task_id": "SHAKEDOWN-10",
  "title": "SHAKEDOWN-10: nested missing structure self-heal",
  "body": "Verifies STEP 0 mkdir -p self-heal for 3-level-deep missing nested structure.",
  "head": "sandbox/test-10-nested-missing",
  "base": "sandbox-staging-T1",
  "files_changed": ["MARKERS/SHAKEDOWN-10.txt", "MARKERS/SHAKEDOWN-10/sub/inner.txt"],
  "simulated": true,
  "self_healed_paths": ["MARKERS/SHAKEDOWN-10/", "MARKERS/SHAKEDOWN-10/sub/", "MARKERS/SHAKEDOWN-10/sub/inner.txt"],
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

git add MARKERS/SHAKEDOWN-10.txt MARKERS/SHAKEDOWN-10 PR_SIMULATIONS/SHAKEDOWN-10.json
echo "WORK done"
```

## Acceptance criteria
```bash
test -f MARKERS/SHAKEDOWN-10.txt && grep -qF "nested-self-heal-pass-2026-05-03" MARKERS/SHAKEDOWN-10.txt
test -d MARKERS/SHAKEDOWN-10/sub
test -f MARKERS/SHAKEDOWN-10/sub/inner.txt && grep -qF "inner-pass" MARKERS/SHAKEDOWN-10/sub/inner.txt
test -f PR_SIMULATIONS/SHAKEDOWN-10.json
```

## Pivot triggers
- If `mkdir -p` fails with permission denied → write stuck reports; class is `permissions` (not `filesystem`); orchestrator may need to escalate to human.

## STUCK PROTOCOL
Standard. Most likely stuck cause is permission denied on `mkdir -p`.

## 3-strikes rule
Standard.

## Open PR
PR simulation in WORK section.
