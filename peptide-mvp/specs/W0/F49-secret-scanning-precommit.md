---
task_id: F49
title: "Add secret-scanning pre-commit hook (gitleaks)"
wave: W0
tier: 2
depends_on: [F104]
blocks: []
files_owned:
  - .gitleaks.toml
  - .husky/pre-commit
  - package.json
must_read_before_writing:
  - peptide-mvp/CODEBASE-CONVENTIONS.md
  - .husky/pre-commit
  - package.json
schema_dependencies: []
vendor_blocks: []
estimated_effort: 0.25d
---

## User capability delivered

Engineers cannot accidentally commit Stripe / DoseSpot / Supabase / Postmark / Twilio secrets. Pre-commit hook fails the commit before secrets reach git history.

## Coordination warning

This task touches `package.json`. So does `W0-package-json-cleanup`. **F49 must dispatch AFTER `W0-package-json-cleanup` lands** to avoid merge conflict. Add explicit `depends_on: [W0-package-json-cleanup]` in the executor's marker if it isn't already complete at dispatch time.

## Technical scope

1. **Install gitleaks as a devDependency:**
   - `npm install --save-dev gitleaks` (npm-published binary wrapper) OR
   - if the project standard is to use a system binary: add to `README.md` install instructions and skip the npm install.
   - Pick whichever the existing tooling pattern supports — read `.husky/`, `.pre-commit-config.yaml` (if present), and `package.json` `scripts` to determine.

2. **Create `.gitleaks.toml`** at repo root with rules covering:
   - Stripe live + test keys (`sk_live_`, `sk_test_`, `rk_live_`, `whsec_`)
   - Supabase service-role JWT (long JWTs starting `eyJhbGciOi...` in non-test files)
   - DoseSpot API keys (per their key format — read DoseSpot docs link)
   - Generic high-entropy strings in `.env*` files
   - Allowlist `.env.example` and `tests/fixtures/` (these contain dummy values intentionally)

3. **Add to `.husky/pre-commit`** (create if missing — husky already in devDeps per master list):
   ```sh
   #!/usr/bin/env sh
   . "$(dirname -- "$0")/_/husky.sh"

   npx gitleaks protect --staged --redact --config .gitleaks.toml
   ```

4. **Add npm script for CI use:**
   - `"scan:secrets": "gitleaks detect --redact --config .gitleaks.toml"`
   - CI calls this on PRs.

## Verifiable acceptance criteria

```bash
# (a) config exists
[ -f .gitleaks.toml ]

# (b) hook exists and is executable
[ -x .husky/pre-commit ]
grep -q "gitleaks" .husky/pre-commit

# (c) script wired
grep -q '"scan:secrets"' package.json

# (d) hook actually catches a fake secret (positive test)
TMP=$(mktemp)
echo 'STRIPE_KEY="sk_live_FAKE_TEST_1234567890abcdef1234567890abcdef"' > $TMP
git add $TMP
! npx gitleaks protect --staged --redact --config .gitleaks.toml  # MUST exit nonzero
git reset HEAD $TMP
rm $TMP

# (e) hook does NOT block a clean staged file (negative test)
echo "console.log('hello');" > /tmp/clean.ts
git add /tmp/clean.ts
npx gitleaks protect --staged --redact --config .gitleaks.toml  # MUST exit zero
git reset HEAD /tmp/clean.ts
rm /tmp/clean.ts

# (f) build + typecheck pass
npm run build
npm run typecheck
```

## Pivot triggers

- If husky is NOT installed: do NOT silently install it — report and escalate. The hook lifecycle install affects every contributor's git config.
- If existing `.husky/pre-commit` already runs other commands: append, don't overwrite.
- If `gitleaks detect` finds existing secrets in current `main` (not just staged changes): halt — F49 has uncovered a P0 leak. Escalate immediately, do not commit.

## Notes for executor

The negative test in (e) is critical — a hook that always fails is worse than no hook (engineers will `--no-verify` and never look back).
