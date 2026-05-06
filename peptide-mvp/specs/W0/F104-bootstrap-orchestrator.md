---
task_id: F104
title: Bootstrap orchestrator infrastructure in peptide-website repo
type: ADD
effort: M (1.5d)
phase: A
wave: W0
priority_score: 999
status: 🟥 Not built
depends_on: []
blocks: ALL_OTHER_W0_TASKS
files_owned:
  - .orchestrator/             # NEW directory (gitignored except STATE/, MARKERS/, etc.)
  - STATE/                     # NEW (gitignored at peptide-website level)
  - MARKERS/                   # NEW (gitignored)
  - PR_SIMULATIONS/            # NEW (gitignored)
  - STUCK_STATE/               # NEW (gitignored)
  - INTEGRATION_FAILURES/      # NEW (gitignored — keep dir but ignore contents)
  - PREFLIGHT_BASELINE/        # NEW (gitignored)
  - preflight.sh               # NEW (peptide-website-specific)
  - integration-test.sh        # NEW
  - CLAUDE.md                  # NEW or APPEND if exists (peptide-website hard rules)
  - CODEBASE-CONVENTIONS.md    # NEW (copy from /home/user/Orchestrator_Test/peptide-mvp/)
  - EXISTING-CODE-MAP.md       # NEW
  - SCHEDULING-DAG.md          # NEW (W0 portion only at this point)
  - HOLDS.md                   # NEW
  - VENDOR-TRACKER.md          # NEW
  - .gitignore                 # APPEND (add orchestrator-managed paths)
must_read_before_writing:
  - /home/user/Orchestrator_Test/ORCHESTRATOR.md       # the validated protocol from shakedown
  - /home/user/Orchestrator_Test/CLAUDE.md             # template for hard rules section
  - /home/user/Orchestrator_Test/preflight.sh          # template for shell-script pattern
  - /home/user/Orchestrator_Test/integration-test.sh   # template
  - /home/user/Orchestrator_Test/peptide-mvp/CODEBASE-CONVENTIONS.md  # the source doc to copy
  - peptide-website/package.json  # confirm npm scripts exist (typecheck, build, test)
  - peptide-website/.gitignore    # don't double-add
schema_dependencies: []  # no schema changes in W0
---

## User capability

Orchestrator + executor subagents can dispatch work against `peptide-website` with the same protocol that passed the shakedown — including STATE-file durability, double-blind heal subprotocol, parallel dispatch with file-overlap safety, and verifiable acceptance criteria per task.

## Technical scope

### 1. Copy the validated orchestrator protocol files

From `/home/user/Orchestrator_Test/`:
- `ORCHESTRATOR.md` → `peptide-website/ORCHESTRATOR.md`
- `SPEC_TEMPLATE.md` → `peptide-website/SPEC_TEMPLATE.md` (already at v3 from L-001 lesson)
- `SPEC_LESSONS.md` → `peptide-website/SPEC_LESSONS.md`
- `FAILURE_PATTERNS.md` → `peptide-website/FAILURE_PATTERNS.md`
- `ORCHESTRATOR_LOG.md` → `peptide-website/ORCHESTRATOR_LOG.md` (empty template)

### 2. Create peptide-website-specific `CLAUDE.md`

Copy hard-rules section from shakedown's `CLAUDE.md` and adapt:

```md
# peptide-website — Repo-scoped Instructions

## Hard rules (override anything else)

1. NEVER `git push origin main` — only push to `sandbox-staging-W<N>` branches
2. NEVER `git push --force` anywhere
3. NEVER use `gh pr create` until orchestrator is past iteration 1
4. NEVER global git config writes
5. NEVER write outside this repo's tree
6. NEVER call DoseSpot, Quest, Daily.co, Stripe LIVE endpoints from executor sandbox — sandbox/test endpoints only
7. NEVER bypass `requireAuth()` even in tests (use mock sessions)
8. NEVER `createServiceClient()` on patient-facing routes
9. NEVER add hardcoded user IDs (F9 lesson)
10. NEVER skip Zod validation on new POST/PATCH routes
11. NEVER write a migration in a feature task — wave-batch only (per ORCHESTRATOR.md)
12. NEVER include PHI in commit messages, branch names, or log lines
13. ALL subagents you spawn inherit these hard rules
```

### 3. Build peptide-website-specific `preflight.sh`

Adapt shakedown's preflight with peptide-specific checks. Key sections:

```bash
#!/bin/bash
# preflight.sh — peptide-website orchestrator preflight

set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"

WAVE="${1:-W0}"
MODE="${2:-quick}"  # quick | full | baseline

# Check 00 — filesystem
check_filesystem() {
  echo "[00_filesystem] checking required folders + files"
  for d in STATE MARKERS PR_SIMULATIONS STUCK_STATE INTEGRATION_FAILURES PREFLIGHT_BASELINE peptide-mvp/specs; do
    [[ -d "$REPO_ROOT/$d" ]] || { echo "[00_filesystem] MISSING $d"; return 1; }
  done
  for f in ORCHESTRATOR.md CLAUDE.md SPEC_TEMPLATE.md FAILURE_PATTERNS.md SPEC_LESSONS.md package.json supabase/migrations; do
    [[ -e "$REPO_ROOT/$f" ]] || { echo "[00_filesystem] MISSING $f"; return 1; }
  done
  echo "[00_filesystem] OK"
}

# Check 10 — env vars (warn-only at MVP)
check_env_vars() {
  echo "[10_env_vars] checking required env vars (warn-only)"
  for v in NEXT_PUBLIC_SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY; do
    [[ -n "${!v:-}" ]] || echo "[10_env_vars] WARN: $v not set (acceptable in dev)"
  done
  echo "[10_env_vars] OK"
}

# Check 20 — npm install + typecheck baseline
check_npm() {
  echo "[20_npm] checking npm install + typecheck"
  [[ -d "$REPO_ROOT/node_modules" ]] || { echo "[20_npm] MISSING node_modules; run 'npm install'"; return 1; }
  npm run typecheck 2>&1 | grep -v "investor-relations" | grep -E "error TS" && {
    echo "[20_npm] FAIL: new typecheck errors outside investor-relations (F1 hold)"
    return 1
  } || echo "[20_npm] OK (investor-relations errors ignored per F1 hold)"
}

# Check 30 — migrations (no collisions, no in-flight schema work outside batch)
check_migrations() {
  echo "[30_migrations] checking migration sequence + collisions"
  local dups=$(ls "$REPO_ROOT/supabase/migrations/" | sed 's/_.*//' | sort | uniq -d)
  if [[ -n "$dups" ]]; then
    echo "[30_migrations] FAIL: duplicate migration numbers: $dups"
    echo "  (Note: F63 is a known W0 fix for the 018 collision)"
    return 1
  fi
  echo "[30_migrations] OK"
}

# Check 40 — branch
check_branch() {
  echo "[40_branch] checking current branch"
  local current=$(git rev-parse --abbrev-ref HEAD)
  case "$current" in
    sandbox-staging-W*|main) echo "[40_branch] OK (on $current)" ;;
    *) echo "[40_branch] FAIL: on $current; expected sandbox-staging-W* or main"; return 1 ;;
  esac
}

# Check 50 — files_owned reservation (catches parallel-dispatch overlap)
check_files_owned() {
  echo "[50_files_owned] checking in-flight files_owned reservations"
  local conflicts=$(python3 "$REPO_ROOT/.orchestrator/check-files-owned.py" 2>&1 || echo "no checker")
  [[ "$conflicts" =~ "no checker" ]] || [[ -z "$conflicts" ]] || { echo "[50_files_owned] FAIL: $conflicts"; return 1; }
  echo "[50_files_owned] OK"
}

# Check 70 — quotas (placeholder; F104 inherits the simulated trigger from shakedown's P-005)
check_quotas() {
  echo "[70_quotas] checking external quotas"
  [[ -f "$REPO_ROOT/STATE/.simulated_quota_exhausted" ]] && { echo "[70_quotas] FAIL: sentinel"; return 1; }
  echo "[70_quotas] OK"
}

# Check 99 — STATE shape
check_state_shape() {
  echo "[99_state_shape] checking STATE/*.json valid JSON"
  for f in "$REPO_ROOT"/STATE/*.json; do
    [[ -f "$f" ]] && python3 -c "import json; json.load(open('$f'))" || { echo "[99_state_shape] FAIL: $f"; return 1; }
  done
  echo "[99_state_shape] OK"
}

run_full() {
  local fail=0
  check_filesystem || fail=1
  check_env_vars || fail=1
  check_npm || fail=1
  check_migrations || fail=1
  check_branch || fail=1
  check_files_owned || fail=1
  check_quotas || fail=1
  check_state_shape || fail=1
  if [[ $fail -ne 0 ]]; then
    echo "[preflight] FAILED — see issues above; do NOT dispatch tasks"
    exit 1
  fi
  echo "[preflight] all checks passed"
}

# ... baseline + quick mode logic same as shakedown's preflight.sh ...

case "${1:-}" in
  --wave=*) WAVE="${1#--wave=}" ;;
esac
case "${2:-${MODE:-full}}" in
  --baseline) MODE="baseline" ;;
  --quick) MODE="quick" ;;
  --full|*) MODE="full" ;;
esac

# (rest matches shakedown's preflight.sh structure)
```

### 4. Create the STATE files

Initialize empty STATE/*.json files matching shakedown's schema:

```json
// STATE/running.json
{ "wave": "W0", "executors": [], "last_updated": "2026-05-05T00:00:00Z", "schema_version": 1 }

// STATE/pending_review.json — same shape, "prs": []
// STATE/pending_merge.json — same shape, "prs": []
// STATE/completed.json — { "tasks": [] }
// STATE/stuck.json — { "tasks": [] }
// STATE/eligible.json — { "tasks": [] }
```

### 5. Set up `.gitignore` additions

Append to peptide-website's `.gitignore`:

```
# Orchestrator runtime state (per-machine, transient)
STATE/.simulated_quota_exhausted
MARKERS/*.txt
PR_SIMULATIONS/*.json
STUCK_STATE/*.md
INTEGRATION_FAILURES/*.md
PREFLIGHT_BASELINE/.preflight-baseline-*

# Orchestrator artifacts NOT yet ready for commit
.orchestrator/

# But KEEP the directories themselves (so executor finds them)
!STATE/.gitkeep
!MARKERS/.gitkeep
!PR_SIMULATIONS/.gitkeep
!STUCK_STATE/.gitkeep
!INTEGRATION_FAILURES/.gitkeep
```

Place `.gitkeep` files in each directory.

### 6. Copy planning docs

From `/home/user/Orchestrator_Test/peptide-mvp/`:
- `W0-PLAN.md` → `peptide-website/peptide-mvp/W0-PLAN.md`
- `HOLDS.md` → `peptide-website/peptide-mvp/HOLDS.md`
- `VENDOR-TRACKER.md` → `peptide-website/peptide-mvp/VENDOR-TRACKER.md`
- `CODEBASE-CONVENTIONS.md` → `peptide-website/peptide-mvp/CODEBASE-CONVENTIONS.md`
- `SCHEDULING-DAG.md` → `peptide-website/peptide-mvp/SCHEDULING-DAG.md`
- `specs/W0/*` → `peptide-website/peptide-mvp/specs/W0/`

### 7. Cut the wave-staging branch

```bash
git checkout main
git pull origin main
git checkout -b sandbox-staging-W0
```

All W0 work merges into `sandbox-staging-W0`. PR-to-`main` happens at end of wave (not per-task).

## Acceptance criteria (verifiable)

```bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# Working directory is peptide-website
[[ "$(basename $(pwd))" = "peptide-website" ]]

# Orchestrator protocol files present
for f in ORCHESTRATOR.md CLAUDE.md SPEC_TEMPLATE.md SPEC_LESSONS.md FAILURE_PATTERNS.md ORCHESTRATOR_LOG.md preflight.sh integration-test.sh; do
  [[ -f "$f" ]] || { echo "MISSING: $f"; exit 1; }
done

# Planning docs present
for f in peptide-mvp/W0-PLAN.md peptide-mvp/HOLDS.md peptide-mvp/VENDOR-TRACKER.md peptide-mvp/CODEBASE-CONVENTIONS.md peptide-mvp/SCHEDULING-DAG.md; do
  [[ -f "$f" ]] || { echo "MISSING: $f"; exit 1; }
done

# State directories exist
for d in STATE MARKERS PR_SIMULATIONS STUCK_STATE INTEGRATION_FAILURES PREFLIGHT_BASELINE peptide-mvp/specs/W0; do
  [[ -d "$d" ]] || { echo "MISSING: $d"; exit 1; }
done

# STATE/*.json files are valid JSON
for f in STATE/*.json; do
  python3 -c "import json; json.load(open('$f'))" || { echo "INVALID JSON: $f"; exit 1; }
done

# Preflight passes baseline
bash preflight.sh --wave=W0 --baseline

# .gitignore updated
grep -q "STATE/.simulated_quota_exhausted" .gitignore

# CLAUDE.md has the peptide-specific hard rules (spot-check rule 11)
grep -q "wave-batch only" CLAUDE.md

# CODEBASE-CONVENTIONS references audit findings
grep -q "F65" peptide-mvp/CODEBASE-CONVENTIONS.md
grep -q "F66" peptide-mvp/CODEBASE-CONVENTIONS.md

# On expected branch
[[ "$(git rev-parse --abbrev-ref HEAD)" = "sandbox-staging-W0" ]]

# F104 marker written
[[ -f MARKERS/F104.txt ]]
grep -q "bootstrap-complete-2026-05" MARKERS/F104.txt

echo "F104 acceptance criteria PASS"
```

## Pivot triggers

- If `npm install` fails persistently (lockfile corruption, node version mismatch): ABANDON in-place, file `F104-A` to fix the build environment first.
- If `preflight.sh` baseline run fails on legitimate repo state (not a bug in preflight): the preflight is wrong; iterate the script before writing the marker.
- If peptide-website's existing CLAUDE.md (if any) has rules conflicting with the new ones: STUCK PROTOCOL — surface to human for reconciliation, do not silently override.

## Notes for executor

- This is a foundation task — getting it right matters more than getting it fast.
- Don't try to set up W1/W2/W3 specs in this task. F104 only sets up W0 + the planning doc set; specs for other waves come in their own bootstrap tasks (or ad-hoc).
- The `.orchestrator/check-files-owned.py` script is a stub for now; full implementation can come in a follow-up task. Preflight check 50 will pass-through if the script doesn't exist (per the `|| echo "no checker"` guard).
- Production `peptide-website` deploys are frozen at `3f5b0ea` per F1 hold. Your work merges to `sandbox-staging-W0` which feeds into `main` at end of wave. NOTHING from this orchestrator work touches the live site until F1 unfreezes.
