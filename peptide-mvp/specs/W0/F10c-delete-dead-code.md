---
task_id: F10c
title: "Delete 21 dead-code files (NOT v1 LLM generator)"
wave: W0
tier: 2
depends_on: [F10a]
blocks: []
files_owned:
  # 21 files to be deleted — see Technical scope §1.
  # Listed here only for reservation; executor performs deletion, not edit.
must_read_before_writing:
  - peptide-mvp/CODEBASE-CONVENTIONS.md
  - peptide-mvp/EXISTING-CODE-MAP.md
schema_dependencies: []
vendor_blocks: []
estimated_effort: 0.5d
---

## User capability delivered

None — bulk dead-code removal. Reduces surface area for security review, shrinks bundle eligibility cone, lowers maintenance burden.

## Background

Per master list F10c: 21 files identified as unreferenced, undeployed dead code. F10a (admin-gate) explicitly carved OUT the v1 LLM generator (`app/api/protocol/generate/route.ts`) — that file is gated, NOT deleted, since admin tooling still uses it.

This task depends on F10a having landed first to ensure the admin gate is in place before anything around the v1 generator gets touched.

## Technical scope

1. **Re-verify the dead-file list before deleting.** Master list claims 21 files; do not trust blindly. For each candidate file:
   ```bash
   FILE="<candidate>"
   # confirm zero importers
   rg --files-with-matches -F "$FILE" --glob '!node_modules' --glob '!.next' || echo "DEAD: $FILE"
   # also check string references (route handlers etc.)
   BASENAME=$(basename "$FILE" | sed 's/\.[^.]*$//')
   rg "$BASENAME" --glob '*.ts' --glob '*.tsx' --glob '*.json' app components lib
   ```
2. Build the verified delete-list. Submit it as part of the executor's marker before deletion (orchestrator review gate).
3. After approval: `git rm` each file. Single commit, named `chore(W0/F10c): delete 21 verified dead-code files`.
4. Touch nothing else. If a deletion breaks the build, that file was NOT dead — restore it, remove from list, report.

**Explicitly excluded (do not delete):**
- `app/api/protocol/generate/route.ts` (gated by F10a)
- Any file in `lib/convergence/v1/` that is referenced by the gated v1 route
- Any file under `supabase/migrations/`

## Verifiable acceptance criteria

```bash
# (a) build passes after deletions
npm run build

# (b) typecheck passes
npm run typecheck

# (c) Vitest unit suite passes (catches removed-but-still-imported test fixtures)
npm test --run

# (d) git diff is delete-only — no modifications
[ "$(git diff --name-only --diff-filter=M main | wc -l)" = "0" ]

# (e) v1 generator route still exists (not in the delete list)
[ -f app/api/protocol/generate/route.ts ]

# (f) marker reports the actual delete count
grep -E "deleted [0-9]+ files" MARKERS/F10c-*.md
```

## Pivot triggers

- If verification finds <15 actually-dead files: continue with the smaller verified list, document the discrepancy.
- If verification finds the master-list count was wildly wrong (<5 actually-dead): halt, report — this likely means F0a-equivalent re-audit was required first.
- If `npm test` fails after deletion of file X: that file was a test fixture — restore it, remove from list.

## Notes for executor

This task is the highest-risk W0 item even though it's effort 0.5d. Bulk deletes have a long history of taking out load-bearing files that look unreferenced because they're loaded dynamically (Next.js route segments, glob imports, MDX content). Verify each file twice.

The marker MUST list every deleted file. This is for forensic recovery if a regression surfaces later.
