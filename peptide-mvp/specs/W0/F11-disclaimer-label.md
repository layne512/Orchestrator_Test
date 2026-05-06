---
task_id: F11
title: "Disclaimer label change in build-protocol intake step"
wave: W0
tier: 1
depends_on: [F104]
blocks: []
files_owned:
  - components/intake/step-build-protocol.tsx
must_read_before_writing:
  - peptide-mvp/CODEBASE-CONVENTIONS.md
  - components/intake/step-build-protocol.tsx
schema_dependencies: []
vendor_blocks: []
estimated_effort: 0.1d
---

## User capability delivered

Patient sees the legally-correct disclaimer text on the intake build-protocol step.

## Technical scope

1. Open `components/intake/step-build-protocol.tsx`.
2. Find the disclaimer paragraph currently rendered above the protocol-builder controls. Current text (per master list F11): "This is not medical advice."
3. Replace with: **"This intake collects information for review by a licensed physician. It is not a prescription and does not establish a doctor-patient relationship until the consult is completed."**
4. No styling changes. No layout changes. Single-string replacement.

## Verifiable acceptance criteria

```bash
# (a) new text present
grep -q "does not establish a doctor-patient relationship" components/intake/step-build-protocol.tsx

# (b) old text absent
! grep -q "This is not medical advice." components/intake/step-build-protocol.tsx

# (c) only one file changed
[ "$(git diff --name-only main | wc -l)" = "1" ]

# (d) build passes
npm run build

# (e) typecheck passes
npm run typecheck
```

## Pivot triggers

- If the disclaimer text is in a different file (extracted to a constants file, e.g. `lib/intake/copy.ts`): edit that file instead, update `files_owned` in the executor's marker, otherwise leave behavior identical.
- If the disclaimer is rendered from a CMS / DB field: halt and report — this becomes a data task, not a code task.

## Notes for executor

Trivial. Largest risk is the executor not finding the literal current text — search for "medical advice" if the exact string differs.
