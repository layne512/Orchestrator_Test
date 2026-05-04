# Orchestrator Shakedown Test

A self-contained test harness for validating the orchestrator + subagent protocol that will run the PeptideOS MVP aperant work. **This repo is throwaway.** When the 11 shakedown scenarios pass, the protocol is trusted and we apply it to the real `peptide-website` repo.

## What this validates

- Orchestrator agent reading task specs + STATE files + dispatching executors via Agent tool
- **Dispatch ordering** via `dependencies` in spec frontmatter
- **Merge ordering** via `merge_order_after` in spec frontmatter
- **Parallel-safe dispatch** via `files_owned` (non-overlapping = parallel; overlapping = sequential)
- **Sequential merge with integration test gate** between every merge
- **Stuck-task self-heal** via the two-report double-blind protocol
  - Report 1 (`Error4Orchestrator.md`): short, factual, read FIRST
  - Report 2 (`ErrorDoubleCheck4Orchestrator.md`): detailed KNOW/THINK/FIX/PROPOSE, read AFTER initial diagnosis
- **Failure-analyst subagent** for novel failure patterns
- **Spec-analyst subagent** for spec-induced stuck
- **AI review per task** via `superpowers:code-reviewer`
- **Wave-complete gate** (orchestrator halts and pings human after all 11 done)
- **Multi-cycle in-session loop** (orchestrator runs cycles until wave complete or 2 stuck cycles)

## What this does NOT validate (out of scope for iteration 1)

- Real Next.js typecheck/build/deploy
- Real Supabase migrations
- Vercel preview deploys
- Stripe / Daily / DoseSpot integrations
- Aperant's GUI integration depth (orchestrator runs via Claude Code session; Aperant is the launcher in iteration 2)

## Setup

See `INSTALL.md` for comprehensive new-Mac setup. TL;DR:

```bash
# Already installed Mac dev tools? Skip to Phase 6.
# Otherwise, follow INSTALL.md Phase 1-5.

mkdir -p ~/Documents && cd ~/Documents
gh repo clone layne512/Orchestrator_Test ./Orchestrator_Test
cd Orchestrator_Test
git checkout -b sandbox-staging-T1
bash preflight.sh --wave=T1 --baseline
claude
```

Then in the Claude Code session, paste the trigger prompt from `INSTALL.md` Phase 7.

## The 11 shakedowns

| # | What it tests | Designed to | Est. clock |
|---|---|---|---|
| 01 | Happy path — baseline dispatch → review → merge → tag | PASS | 5 min |
| 02 | Missing-file stuck heal protocol | FAIL (P-001 match) | 10 min |
| 03 | Pattern match (existing P-002, env var) | FAIL (recurrence++) | 8 min |
| 04 | Pattern match (new) — failure-analyst spawn + merge ordering | FAIL (new P-005) | 15 min |
| 05 | Integration test fail — auto-revert + FIX flow | PASS then revert | 12 min |
| 06 | Parallel preflight inheritance | PASS (parallel-safe) | 20 min |
| 07 | Corruption recovery (Phase 1 normal; Phase 2 manual injection) | PASS Phase 1 | 15 min |
| 08 | Wave QA gate — depends on all others | PASS (last) | 5 min |
| 09 | Spec-induced stuck — spec-analyst spawn | FAIL (L-001) | 12 min |
| 10 | Nested missing structure — STEP 0 mkdir -p self-heal | PASS | 10 min |
| 11 | Double-blind diagnostic — Report 1 vs Report 2 differ | FAIL by design | 12 min |

**Total estimated wall-clock:** ~2 hours if everything works; ~3-4 hours with iteration.

## Layout

```
.
├── README.md                  ← you are here
├── INSTALL.md                 ← comprehensive new-Mac setup
├── CLAUDE.md                  ← repo-scoped instructions; loaded by Claude Code
├── ORCHESTRATOR.md            ← complete orchestrator operating manual
├── ORCHESTRATOR_LOG.md        ← append-only cycle log; grows during run
├── SCHEDULING_DAG.md          ← shakedown DAG + priority scores
├── SPEC_TEMPLATE.md           ← canonical task spec template (v2 with stuck protocol)
├── SPEC_LESSONS.md            ← spec authoring lessons (grows during run)
├── FAILURE_PATTERNS.md        ← failure pattern library + analyst contract; 4 seed patterns
├── preflight.sh               ← comprehensive filesystem + branch + JSON validity
├── integration-test.sh        ← post-merge gate (marker existence + content)
├── .gitignore                 ← per-machine baseline + transient files
├── STATE/
│   ├── eligible.json
│   ├── running.json
│   ├── pending_review.json
│   ├── pending_merge.json
│   ├── completed.json
│   └── stuck.json
├── STUCK_STATE/               ← stuck-task recovery anchors (2 reports per stuck task)
├── INTEGRATION_FAILURES/      ← forensic logs for failed merges (SHAKEDOWN-05)
├── MERGE_QUEUE/               ← orchestrator's ordered merge queue
├── PREFLIGHT_BASELINE/        ← per-machine checksum baselines (gitignored)
├── MARKERS/                   ← where executors write their proof-of-work
├── PR_SIMULATIONS/            ← simulated PR metadata (no real GH PRs in iter 1)
└── SHAKEDOWN/
    ├── SHAKEDOWN-01_happy-path.md
    ├── SHAKEDOWN-02_missing-file-stuck.md
    ├── SHAKEDOWN-03_pattern-match-existing.md
    ├── SHAKEDOWN-04_pattern-match-new.md
    ├── SHAKEDOWN-05_integration-fail.md
    ├── SHAKEDOWN-06_parallel-preflight-inheritance.md
    ├── SHAKEDOWN-07_corruption-recovery.md
    ├── SHAKEDOWN-08_wave-qa-gate.md
    ├── SHAKEDOWN-09_spec-induced-stuck.md
    ├── SHAKEDOWN-10_nested-missing-structure.md
    └── SHAKEDOWN-11_double-blind-diagnostic.md
```

## Verifying the run

After the orchestrator finishes (wave-complete or escalated), see `INSTALL.md` Phase 9 for the verification command block. Paste output to whoever's helping you analyze.

## Cleanup

```bash
cd ~ && rm -rf Documents/Orchestrator_Test
gh repo archive layne512/Orchestrator_Test   # or delete with --yes
```

The repo is throwaway. After validation, real MVP work happens in `peptide-website` per the production design.
