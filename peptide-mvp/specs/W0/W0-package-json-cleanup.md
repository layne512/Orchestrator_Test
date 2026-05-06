---
task_id: W0-package-json-cleanup
title: "W0 package.json cleanup (bundles F62 + F70 + F71)"
wave: W0
tier: 1
depends_on: [F104]
blocks: []
files_owned:
  - package.json
  - package-lock.json
must_read_before_writing:
  - peptide-mvp/CODEBASE-CONVENTIONS.md
  - peptide-mvp/EXISTING-CODE-MAP.md
  - package.json
schema_dependencies: []
vendor_blocks: []
estimated_effort: 0.5d
---

## User capability delivered

None — this is a hygiene task. No user-visible behavior change.

## Why bundled

F62, F70, F71 all mutate `package.json`. Dispatched in parallel they collide every time. Bundling them into one PR turns three race-prone tasks into one safe one.

## Technical scope

1. **F62 — remove unused `ai` SDK package**
   - `npm uninstall ai`
   - Confirm no source file imports from `'ai'`: `rg "from ['\"]ai['\"]" app components lib` returns zero matches.

2. **F70 — audit + remove `postgres` devDep**
   - `npm ls postgres` to confirm it's a devDep, not a transitive.
   - `rg "from ['\"]postgres['\"]|require\(['\"]postgres['\"]\)" .` returns zero matches.
   - If clean: `npm uninstall postgres`.
   - If anything imports it, halt and report — do not remove.

3. **F71 — move `@types/web-push` to devDependencies**
   - In current `package.json`, `@types/web-push` is in `dependencies`. Move to `devDependencies`.
   - Run `npm install` to refresh lockfile.

## Verifiable acceptance criteria

```bash
# (a) ai package gone
! grep -q '"ai":' package.json

# (b) postgres devDep gone (assuming audit cleared)
! grep -q '"postgres":' package.json

# (c) @types/web-push in devDependencies, not dependencies
node -e "const p=require('./package.json'); process.exit(p.devDependencies['@types/web-push'] && !p.dependencies?.['@types/web-push'] ? 0 : 1)"

# (d) install + build still pass
npm install
npm run build

# (e) typecheck passes
npm run typecheck
```

All five must exit 0.

## Pivot triggers

- If `rg` finds any code using `ai` or `postgres`: halt, report which files, do NOT remove.
- If build fails after removal: revert just the failing dep removal, keep the others, report.

## Notes for executor

This is the cleanest possible W0 task — three one-line edits to one file. The whole task should be < 30 minutes including build verification.
