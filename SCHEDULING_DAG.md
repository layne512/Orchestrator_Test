# Scheduling DAG — Shakedown Wave T1

## Wave T1 — orchestrator shakedown scenarios

```
SHAKEDOWN-01 (happy path) ────────────────────────────────────┐
SHAKEDOWN-02 (missing-file stuck) ────────────────────────────┤
SHAKEDOWN-03 (pattern match existing) ────────────────────────┤
SHAKEDOWN-04 (pattern match new) ─────────────────────────────┼─► T1 complete
SHAKEDOWN-05 (integration fail + auto-revert) ────────────────┤
SHAKEDOWN-06 (parallel preflight inheritance) ────────────────┤
SHAKEDOWN-07 (corruption recovery) ───────────────────────────┤
SHAKEDOWN-08 (wave QA gate) ──────────────────────────────────┤
SHAKEDOWN-09 (spec-induced stuck) ────────────────────────────┘
```

## Priority scores (initial)

`priority_score = downstream_blocker_count × 100 + estimated_minutes`

| task_id | kind | estimated_min | downstream | priority_score | notes |
|---|---|---:|---:|---:|---|
| SHAKEDOWN-01 | TEST | 5 | 0 | 5 | Happy path; run first to confirm baseline works |
| SHAKEDOWN-02 | TEST | 10 | 0 | 10 | Stuck heal; must run after 01 to be observable |
| SHAKEDOWN-03 | TEST | 8 | 0 | 8 | Pattern match (existing) |
| SHAKEDOWN-04 | TEST | 15 | 0 | 15 | Pattern match (new); spawns failure-analyst |
| SHAKEDOWN-05 | TEST | 12 | 0 | 12 | Integration fail; tests revert path |
| SHAKEDOWN-06 | TEST | 20 | 0 | 20 | Parallel inheritance; needs 2 tasks dispatched |
| SHAKEDOWN-07 | TEST | 15 | 0 | 15 | Corruption recovery; manually inject fault |
| SHAKEDOWN-08 | TEST | 5 | 0 | 5 | Wave QA gate; triggered after the 7 prior |
| SHAKEDOWN-09 | TEST | 12 | 0 | 12 | Spec-induced stuck; spawns spec-analyst |

## Run order recommendation

Run in numeric order (01 → 09). Each shakedown is designed to verify a specific orchestrator behavior; doing them in order builds confidence incrementally.

## Dispatch policy for shakedown

Iteration 1 deliberately uses **1 task per cycle** (not max parallelism) so observability is maximal — you see each cycle's full effect on STATE files before the next cycle introduces new state. After all 9 pass, we test parallel dispatch in iteration 2.

**Exception:** SHAKEDOWN-06 specifically tests parallel-task preflight inheritance — that scenario instructs the orchestrator to dispatch two tasks simultaneously and observe propagation.

## Currently scheduled

Only `SHAKEDOWN-01_happy-path.md` is present in `SHAKEDOWN/` at initial commit. The other 8 are added iteratively as each prior shakedown validates.
