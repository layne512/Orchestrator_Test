# Failure Patterns Library

Append-only library of failure classes the orchestration system has learned. Each entry documents a root-cause class and the **generalized check** that prevents the entire class — not just the specific instance.

## Entry template

```markdown
## Pattern P-NNN: <short name>

**First seen:** YYYY-MM-DD (<task-id>)
**Recurrences:** <count> (<task-id-list>)
**Class:** <preflight-missing-X | code-conflict-Y | external-blocker-Z>

**Symptom:** what error/log line surfaces

**Root cause:** plain-language description

**Specific fix:** the targeted patch that addressed THIS instance

**Generalized check (catches THIS + similar):** what the new preflight check verifies, in scope-broadened form

**Other patterns this covers:**
- bullet list of similar root-cause classes the generalization handles

**Prevention scope:** which waves benefit (current + future)
```

## Failure-analyst subagent contract

When a stuck task has no matching pattern here, the orchestrator spawns a `failure-analyst` subagent. It receives:
- Stuck task error trail
- `STUCK_STATE/<task-id>.md` content
- This file

It must return EXACTLY 4 fields per the contract in `ORCHESTRATOR.md` Step 6a.

Orchestrator validates the response and applies — same review-gate pattern as spec-analyst.

---

## Seed patterns (from past stuck-task experience)

## Pattern P-001: Missing referenced file in worktree

**First seen:** seed pattern
**Recurrences:** 1 (SHAKEDOWN-02 on 2026-05-05)
**Class:** preflight-missing-filesystem

**Symptom:** Executor fails with `ENOENT: no such file or directory` when reading a path the task spec referenced.

**Root cause:** Task spec assumed a file existed in the executor's worktree but it wasn't created by an upstream task or wasn't merged into the wave-staging the executor branched from.

**Specific fix:** Verify path before reading; fail fast with the missing path name.

**Generalized check:** STEP 0 self-heal block in every task spec scans paths referenced in the spec body; aborts with explicit "missing X" if not present. preflight.sh check 00_filesystem verifies all required folders/files exist before any executor dispatches.

**Other patterns this covers:**
- Task references a file the rescue branch was supposed to create but didn't
- Task references a file from a sibling branch not yet merged

**Prevention scope:** All tasks (template enforces STEP 0)

---

## Pattern P-002: Missing or empty env var

**First seen:** seed pattern
**Recurrences:** 1 (SHAKEDOWN-03 on 2026-05-05)
**Class:** preflight-missing-env

**Symptom:** Runtime error (NoneType, undefined) on accessing `process.env.X` or `os.getenv("X")`; or service call rejected with auth error.

**Root cause:** Required env var unset in `.env.local` or empty.

**Specific fix:** Check `.env.local` for required keys before any executor work begins.

**Generalized check:** preflight.sh check 10_env_vars reads a required-keys list per wave; verifies each is present and non-empty. (In shakedown iter 1, this check is stubbed because no env vars are required.)

**Other patterns this covers:**
- Service call returns 401 because key is empty
- Build fails because NEXT_PUBLIC_X is missing
- Webhook fails because secret is unset

**Prevention scope:** All waves at wave-start preflight

---

## Pattern P-003: Wrong base branch

**First seen:** seed pattern
**Recurrences:** 0
**Class:** preflight-wrong-branch

**Symptom:** Executor's first commit conflicts with main; rebase produces hundreds of conflicts.

**Root cause:** Executor branched from `main` instead of the active wave-staging.

**Specific fix:** Check current branch; abort if not on a wave-staging-derivative.

**Generalized check:** preflight.sh check 50_branch verifies HEAD is on a branch matching the active wave's pattern (sandbox-staging-T* in iter 1, mvp/w{n}-* in production).

**Other patterns this covers:**
- Branched from a previous wave's staging
- Branched from main while wave was in progress
- Branched from a stale local mvp-staging

**Prevention scope:** All waves at every preflight check

---

## Pattern P-004: Invalid STATE JSON

**First seen:** seed pattern
**Recurrences:** 0
**Class:** preflight-corrupt-state

**Symptom:** Orchestrator fails with JSON parse error reading `STATE/*.json`; cycle aborts before any dispatch.

**Root cause:** A prior cycle wrote malformed JSON to a state file (e.g., truncated write, manual edit gone wrong, git merge conflict markers).

**Specific fix:** Check JSON validity at start of every cycle; restore from git if corrupted.

**Generalized check:** preflight.sh check 99_state_shape parses every `STATE/*.json` with `python3 -c "json.load(open(...))"`; fails if any file is invalid.

**Other patterns this covers:**
- Truncated write from interrupted cycle
- Manual edit error
- Merge conflict markers left in state file

**Prevention scope:** All cycles (preflight runs every cycle)

---

## Pattern P-005: Storage/quota exhaustion

**First seen:** 2026-05-05 (SHAKEDOWN-04)
**Recurrences:** 0

**Class:** external-blocker-quota

**Symptom:** Executor (or STEP 0 self-heal) aborts with a quota / rate-limit / capacity message from an external service — e.g., `STUCK: simulated git LFS quota exhausted (100000000 > 99999999)`, HTTP 429, "rate limit exceeded", "deploy limit reached", "row count exceeded plan", "bucket over quota", exit code 1 before any task work begins.

**Root cause:** A finite resource owned by an external provider (storage bytes, request count per window, deploy minutes, row count, object count) has been consumed up to or beyond its ceiling. The provider rejects the next operation, and because the limit is owned outside the repo, no in-repo code change can clear it; the cycle has to halt and surface the blocker to a human (or wait for a window reset).

**Specific fix:** For the SHAKEDOWN-04 instance, detect the simulated trigger (sentinel file `STATE/.simulated_quota_exhausted` or env `SIMULATED_QUOTA_EXHAUSTED=1`) at preflight and abort before dispatch with a clear message identifying the exhausted quota.

**Generalized check (catches THIS + similar):** preflight.sh check `70_quotas` runs every cycle and probes the set of external quotas relevant to the current wave. In iter 1 it is permissive (returns 0) but honors a sentinel file / env trigger so the orchestrator can deterministically simulate exhaustion. In production iterations the same function is the single home for real probes (LFS quota, GitHub API rate-limit headers, Vercel deploy quota, Supabase row/storage usage, Stripe API rate limit, S3/Cloudflare R2 bucket usage, npm publish rate limit) — each one fails with the specific provider + remaining-headroom string so the orchestrator can route to the right human.

**Other patterns this covers:**
- GitHub REST/GraphQL API rate-limit (HTTP 429 / `X-RateLimit-Remaining: 0`)
- Vercel monthly deploy / build-minute quota
- Supabase free-tier row count or storage cap
- Stripe API per-second request rate limit
- AWS S3 / Cloudflare R2 bucket storage or request quota
- npm publish rate limit / npmjs daily download cap
- OpenAI / Anthropic API token-per-minute quota
- DoseSpot or Daily.co per-plan usage ceiling
- DNS provider record-count limit
- Cloudflare Workers CPU-ms or request quota

**Prevention scope:** All cycles (preflight runs every cycle; `check_quotas` invoked from `run_full()` between `check_branch` and `check_state_shape`). All waves benefit, present and future, because the check is wave-agnostic — only the probe list grows as new external services are integrated.
