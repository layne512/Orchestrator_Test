# Orchestrator Cycle Log

Append-only log of every orchestrator cycle. Each entry captures what the orchestrator did during that cycle.

## Format

```markdown
## YYYY-MM-DD HH:MM:SS UTC — cycle <N>

- on branch: <branch> @ <sha-short>
- preflight: PASS | FAIL (<reason if fail>)
- in-flight before cycle:
  - running: <count>
  - pending_review: <count>
  - pending_merge: <count>
  - stuck: <count>
- actions taken:
  - <verb> <target> — <result>
  - ...
- in-flight after cycle:
  - (counts)
- next eligible: <task-id> | "wave complete" | "all stuck"
- exit reason: dispatched | reviewed | merged | reverted | healed | wave-complete | preflight-blocked | escalated
```

---

(no entries yet — orchestrator has not been invoked)
