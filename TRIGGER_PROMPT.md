# Trigger Prompt — paste this into Aperant or Claude Code

## What this is

The single prompt that kicks off the orchestrator. Copy/paste it into:
- **Aperant**: when creating a new task on the project
- **Claude Code session**: after typing `claude` from the project directory

The orchestrator reads `ORCHESTRATOR.md` from this repo and follows it exactly.

---

## The prompt (copy everything between the lines below)

---
Read ORCHESTRATOR.md and run shakedown cycles continuously until wave T1 is complete or 2 consecutive cycles produce no progress.

Follow ORCHESTRATOR.md exactly. Use its multi-cycle in-session loop per Step 8.

Dispatch executor subagents per the spec for each shakedown task. Use superpowers:code-reviewer for AI review (or general-purpose subagent if superpowers not installed). Sequential-merge with integration test gate after every merge. Heal stuck tasks via the two-report double-blind protocol (read Error4Orchestrator.md FIRST, form initial diagnosis, log it with timestamp, THEN read ErrorDoubleCheck4Orchestrator.md, reconcile, apply final fix).

Update STATE/*.json + ORCHESTRATOR_LOG.md every cycle. Tag every merge and every failed merge.

Exit cleanly with the summary template at the end of ORCHESTRATOR.md when wave T1 is complete OR you've had 2 consecutive cycles with no progress.

---

## Alternative — auto-fire every 5 minutes (hands-off mode)

In a Claude Code session, instead of pasting the prompt above, run:

```
/loop 5m Read ORCHESTRATOR.md and run one shakedown cycle. Start with the highest-priority eligible task. Follow ORCHESTRATOR.md exactly.
```

The orchestrator runs once every 5 min until you stop with `/loop stop`.

---

## Alternative — single cycle (for debugging or stepping through)

```
Read ORCHESTRATOR.md and run ONE cycle only. Stop after dispatching, reviewing, merging, or healing one item. Report what happened. Do NOT loop.
```

Useful when you want to observe each cycle's effect on STATE/* before the next cycle runs.
