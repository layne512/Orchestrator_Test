# Aperant Orchestrator Shakedown Test

A self-contained test harness for validating the orchestrator + subagent protocol designed for the PeptideOS MVP aperant task suite.

**This repo is throwaway.** When the shakedown passes, the orchestration design is proven and we apply it to the real `peptide-website` repo. This repo can then be archived or deleted.

## What this tests

- Orchestrator agent reading task specs + STATE files + dispatching executors via Agent tool
- Sequential merge with integration test gate
- Stuck-task self-heal (WIP commit → STUCK_STATE doc → preflight patch → resume)
- Failure-analyst subagent for novel failure patterns
- Spec-analyst subagent for spec-induced stuck
- AI review per task via `superpowers:code-reviewer`
- Wave-complete gate (orchestrator halts and pings human)
- 9 shakedown scenarios covering every critical path

## What this does NOT test

- Real Next.js typecheck/build/deploy
- Real Supabase migrations
- Vercel preview deploys
- Stripe / Daily / DoseSpot integrations
- Aperant runtime integration (that's iteration 2; this is iteration 1, protocol mechanics only)

## Setup (new Mac, one-time)

See `INSTALL.md` (forthcoming) or follow this conversation's pre-flight install instructions:
1. Xcode CLI tools
2. Homebrew
3. git + gh CLI (auth as personal account, NOT write access to project repos)
4. Node.js
5. Claude Code CLI: `npm install -g @anthropic-ai/claude-code`
6. superpowers plugin: in claude session, `/plugin marketplace add anthropics/claude-code` then `/plugin install superpowers`

## Run a shakedown cycle

```bash
cd ~/aperant_orchestrator_testing   # or wherever you cloned this
git checkout -b sandbox-staging-T1   # one-time, on first run
claude
```

Then in the Claude Code session, paste this prompt:

```
Read ORCHESTRATOR.md and run one shakedown cycle. Start with SHAKEDOWN-01 if no work is in flight.
```

The orchestrator agent will:
1. Read STATE/*.json + SCHEDULING_DAG.md
2. Dispatch the next eligible shakedown task to an executor subagent
3. Wait for the executor to complete
4. AI-review the output (via superpowers:code-reviewer)
5. Run integration-test.sh
6. Squash-merge into sandbox-staging-T1 if green; revert + spawn FIX otherwise
7. Update STATE/*.json + ORCHESTRATOR_LOG.md
8. Exit the cycle

## Observe outcomes

After each cycle, check:
- `STATE/*.json` — what moved between states
- `ORCHESTRATOR_LOG.md` — cycle log entry
- `MARKERS/` — what marker files the executor wrote
- `git log sandbox-staging-T1 --oneline` — merges + reverts
- `git tag` — task-merged-* and failed-merge-* tags
- `STUCK_STATE/`, `INTEGRATION_FAILURES/`, `FAILURE_PATTERNS.md`, `SPEC_LESSONS.md` — failure-handling artifacts

Paste outputs into the conversation with the agent that wrote this; iterate on `ORCHESTRATOR.md` if anything misbehaves.

## Layout

```
.
├── README.md                  ← you are here
├── CLAUDE.md                  ← loaded by Claude Code on session start in this dir
├── ORCHESTRATOR.md            ← orchestrator's complete operating manual
├── ORCHESTRATOR_LOG.md        ← append-only cycle log
├── SCHEDULING_DAG.md          ← shakedown DAG + priority scores
├── SPEC_TEMPLATE.md           ← canonical task spec template
├── SPEC_LESSONS.md            ← spec authoring lessons (grows over time)
├── FAILURE_PATTERNS.md        ← failure pattern library (grows over time)
├── preflight.sh               ← minimal preflight (filesystem + branch + state-files)
├── integration-test.sh        ← minimal integration test (marker file checks)
├── STATE/
│   ├── eligible.json          ← tasks ready to dispatch
│   ├── running.json           ← currently dispatched
│   ├── pending_review.json    ← awaiting AI review
│   ├── pending_merge.json     ← AI-approved, awaiting merge
│   ├── completed.json         ← squash-merged + integration-green
│   └── stuck.json             ← in heal protocol
├── STUCK_STATE/               ← stuck-task recovery anchors
├── INTEGRATION_FAILURES/      ← forensic logs for failed merges
├── MERGE_QUEUE/               ← ordered queue of approved tasks
├── PREFLIGHT_BASELINE/        ← checksum baselines per wave
├── MARKERS/                   ← where dummy executors write their proof-of-work
├── PR_SIMULATIONS/            ← simulated PR metadata (no real GH PRs in iter 1)
└── SHAKEDOWN/
    ├── SHAKEDOWN-01_happy-path.md
    └── ... (added iteratively as each prior shakedown validates)
```

## Cleanup when done

```bash
cd ~
rm -rf aperant_orchestrator_testing
gh repo delete layne512/aperant_orchestrator_testing --yes   # or archive
```
