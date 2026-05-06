# auto-claude branch audit — peptide-website

**Audited on:** 2026-05-05
**Repo:** `peptide-website` (origin/main @ `486f63b add investor-relations dashboard`)
**Branches audited:** 9
**Method:** parallel isolated git worktrees, per-branch fetch + checkout + `npm install` + `npx tsc --noEmit` + `npm run build` + `npm run test` + 2–3 file code review

## Summary table

| Branch | Verdict | Recommendation | Notes |
|---|---|---|---|
| 036-wire-md-schedule-page-with-calendar-component | UNRELATED | ABANDON | branch tip is ancestor of main (0 unique commits); feature already on main; STALE 42d |
| 041-implement-database-driven-medication-catalog-with- | UNRELATED | ABANDON | branch missing from origin |
| 044-migrate-patient-health-history-to-server-side-fetc | UNRELATED | ABANDON | branch missing from origin |
| 048-replace-hardcoded-user-id-in-md-messages | UNRELATED | ABANDON | branch missing from origin |
| 050-integrate-stripe-connect-earnings-data-for-physici | UNRELATED | ABANDON | branch missing from origin |
| 051-verify-md-labs-page-with-real-data-and-edge-cases | UNRELATED | ABANDON | branch missing from origin |
| 052-wire-admin-users-page-with-auth-guard | UNRELATED | ABANDON | branch missing from origin |
| 057-implement-patient-lab-upload-with-ocr-parsing | UNRELATED | ABANDON | branch missing from origin |
| 060-comprehensive-peptide-telehealth-codebase-audit | UNRELATED | ABANDON | branch missing from origin (sequence skips 058 → 068) |

**Headline:** 8 of 9 branches in the requested list do not exist on `origin` at all (041, 044, 048, 050, 051, 052, 057, 060). The one that does (036) has zero unique commits — its tip is an ancestor of `origin/main`, meaning the work it describes is already shipped. Recommend deleting any local refs and removing all 9 entries from any active queue.

---

## auto-claude/036-wire-md-schedule-page-with-calendar-component

**Verdict:** UNRELATED
**Recommendation:** ABANDON
**Staleness:** 42 days (STALE)

**Last commit:** 2026-03-24 01:39:59 -0500 | LayneFontaine | Merge pull request #19 from layne512/auto-claude/033-wire-stripe-webhook-handlers-to-supabase

**Diff stats:**
```
332 files changed, 1870 insertions(+), 600428 deletions(-)
```
(Note: diff against main shows main as "deletions" because branch tip is an ancestor of main with zero unique commits — `git merge-base origin/main branch == branch HEAD == 4c85a31`. There are 0 commits unique to the branch and ~22 commits on main not on the branch.)

**Files changed:** 0 (branch is fully contained in main)
- (none — branch tip is an ancestor of origin/main; no unique commits)

**Build status:**
- npm install: PASS
- npx tsc --noEmit: FAIL
- npm run build: FAIL
- npm run test: PASS (6 files / 118 tests)

Build/typecheck failures all stem from the branch's stale state — its `layout-client.tsx` files import sidebar components (`@/components/dashboard/admin-sidebar`, `md-sidebar`, `patient-sidebar`, `pharmacist-sidebar`, `pharmacy-sidebar`) that were removed/restructured in later main commits:

```
app/dashboard/admin/layout-client.tsx(7,30): error TS2307: Cannot find module '@/components/dashboard/admin-sidebar'
app/dashboard/md/layout-client.tsx(7,27): error TS2307: Cannot find module '@/components/dashboard/md-sidebar'
app/dashboard/patient/layout-client.tsx(7,32): error TS2307: Cannot find module '@/components/dashboard/patient-sidebar'
app/dashboard/pharmacist/layout-client.tsx(7,35): error TS2307: Cannot find module '@/components/dashboard/pharmacist-sidebar'
app/dashboard/pharmacy/layout-client.tsx(7,33): error TS2307: Cannot find module '@/components/dashboard/pharmacy-sidebar'
```

**Code review:** Reviewed `app/dashboard/md/schedule/page.tsx` and `components/md/schedule-calendar.tsx` at the branch tip. The MD schedule page and calendar component are real, well-structured code that wires availability slot CRUD (day/time/duration/consultation_type) for verified MDs — but `git log` shows this work was authored in commit `db9613d` ("auto-claude: subtask-14-3 - Create MD scheduling system with availability calendar"), which is already on `origin/main`. The "036-wire-md-schedule" branch contains no commits beyond a stale ancestor state of main.

**Reasoning:** The branch tip (`4c85a31`) is identical to its merge-base with main, meaning the branch has zero unique commits — there is literally no work on this branch to merge. The MD schedule page and calendar component the branch name describes already exists in main. Build failures are artifacts of the branch being 42 days stale, not of any new work. ABANDON: delete the branch; the feature is already shipped via main.

---

## auto-claude/041-implement-database-driven-medication-catalog-with-

**Verdict:** UNRELATED
**Recommendation:** ABANDON
**Staleness:** N/A (branch does not exist)

**Last commit:** N/A — remote ref not found

**Diff stats:**
```
fatal: couldn't find remote ref auto-claude/041-implement-database-driven-medication-catalog-with-
```

**Files changed:** 0
- (no files — branch missing from origin)

**Build status:**
- npm install: SKIPPED
- npx tsc --noEmit: SKIPPED
- npm run build: SKIPPED
- npm run test: SKIPPED

A `git ls-remote` of `refs/heads/auto-claude/*` confirms branches 040 and 042 exist on origin, but 041 does not. The slot was either never pushed, was deleted, or was renamed.

**Code review:** No code to review — the branch does not exist on the remote, so no diff, no files, and no checkout was possible.

**Reasoning:** The branch is not present on origin (verified via `git ls-remote`). With no commits, files, or build artifacts to evaluate, there is nothing to merge or rebase. Recommend ABANDON; if the work is still wanted, it must be re-created from scratch on a new branch.

---

## auto-claude/044-migrate-patient-health-history-to-server-side-fetc

**Verdict:** UNRELATED
**Recommendation:** ABANDON
**Staleness:** N/A (branch does not exist)

**Last commit:** N/A — branch not found on origin

**Diff stats:**
```
fatal: couldn't find remote ref auto-claude/044-migrate-patient-health-history-to-server-side-fetc
```

**Files changed:** 0
- (no files — branch does not exist)

**Build status:**
- npm install: SKIPPED (no branch to checkout)
- npx tsc --noEmit: SKIPPED
- npm run build: SKIPPED
- npm run test: SKIPPED

The remote ref could not be fetched. `git ls-remote origin 'refs/heads/auto-claude/*'` shows neighboring branches `auto-claude/043-replace-hardcoded-mock-data-with-supabase-queries` and `auto-claude/045-wire-stripe-payment-history-to-patient-dashboard` exist, but slot 044 is absent. No local branch, tag, or alternate ref matches "044" or "patient-health-history" either.

**Code review:** No code to review — the branch does not exist on the remote and no local copy was found. The numbering gap (043 and 045 present, 044 missing) suggests this branch was either never pushed, deleted, or skipped during task allocation.

**Reasoning:** Step 1 (`git fetch`) failed with `fatal: couldn't find remote ref`, which made all subsequent steps impossible. Confirmed via `git ls-remote` that no branch matching this name exists on origin and no local copy exists. There is nothing to merge, rebase, or rewrite, so ABANDON is the only valid recommendation.

---

## auto-claude/048-replace-hardcoded-user-id-in-md-messages

**Verdict:** UNRELATED
**Recommendation:** ABANDON
**Staleness:** N/A (branch does not exist)

**Last commit:** N/A — branch not found on origin

**Diff stats:**
```
fatal: couldn't find remote ref auto-claude/048-replace-hardcoded-user-id-in-md-messages
```

**Files changed:** 0
- (none — branch does not exist on origin)

**Build status:**
- npm install: SKIPPED
- npx tsc --noEmit: SKIPPED
- npm run build: SKIPPED
- npm run test: SKIPPED

`git ls-remote origin "refs/heads/auto-claude/048*"` returned no matches, and `git branch -r | grep 048` was empty.

**Code review:** No code to review — the branch does not exist on origin. No commits, no diff, no files to inspect.

**Reasoning:** The remote ref `auto-claude/048-replace-hardcoded-user-id-in-md-messages` cannot be fetched and is not present in the remote branch listing, so there is nothing to audit, build, or merge. Recommendation is ABANDON since the branch is missing — either it was never pushed or it has already been deleted.

---

## auto-claude/050-integrate-stripe-connect-earnings-data-for-physici

**Verdict:** UNRELATED
**Recommendation:** ABANDON
**Staleness:** N/A (branch not found)

**Last commit:** N/A — branch does not exist on origin

**Diff stats:**
```
fatal: couldn't find remote ref auto-claude/050-integrate-stripe-connect-earnings-data-for-physici
```

**Files changed:** 0
- (none — branch missing)

**Build status:**
- npm install: SKIPPED
- npx tsc --noEmit: SKIPPED
- npm run build: SKIPPED
- npm run test: SKIPPED

A search of `git branch -r` shows no branch matching `050`, `stripe-connect`, or `earnings`. The closest existing Stripe-related branches are `auto-claude/033-wire-stripe-webhook-handlers-to-supabase`, `auto-claude/045-wire-stripe-payment-history-to-patient-dashboard`, and `auto-claude/046-wire-stripe-subscription-status-display`, none of which match this branch name.

**Code review:** No code could be reviewed because the branch was never pushed to origin (or was deleted). There are no files, commits, or diffs to characterize.

**Reasoning:** The fetch in step 1 failed with `fatal: couldn't find remote ref`, and an explicit `ls-remote` confirms no branch with this name exists on origin. With no commits to audit, the only sensible recommendation is ABANDON — there is nothing to merge, rebase, or rewrite.

---

## auto-claude/051-verify-md-labs-page-with-real-data-and-edge-cases

**Verdict:** UNRELATED
**Recommendation:** ABANDON
**Staleness:** N/A (branch does not exist)

**Last commit:** N/A — branch does not exist on origin

**Diff stats:**
```
fatal: couldn't find remote ref auto-claude/051-verify-md-labs-page-with-real-data-and-edge-cases
```

**Files changed:** 0

**Build status:**
- npm install: SKIPPED
- npx tsc --noEmit: SKIPPED
- npm run build: SKIPPED
- npm run test: SKIPPED

`git fetch origin auto-claude/051-verify-md-labs-page-with-real-data-and-edge-cases` failed with exit code 128: `fatal: couldn't find remote ref auto-claude/051-verify-md-labs-page-with-real-data-and-edge-cases`. A subsequent `git ls-remote origin "refs/heads/auto-claude/051-*"` and `git branch -r | grep 051` returned no matches, confirming the branch is absent from the remote.

**Code review:** No code could be reviewed — the branch does not exist on origin, so there are no commits, files, or diffs to inspect.

**Reasoning:** The target branch is not present on the remote, making all subsequent audit steps (checkout, install, build, test, file review) impossible. With no artifact to evaluate, the only sensible recommendation is ABANDON; if the work is needed, it must be (re)created from scratch on a fresh branch.

---

## auto-claude/052-wire-admin-users-page-with-auth-guard

**Verdict:** UNRELATED
**Recommendation:** ABANDON
**Staleness:** N/A (branch does not exist)

**Last commit:** N/A | N/A | branch does not exist on origin

**Diff stats:**
```
fatal: couldn't find remote ref auto-claude/052-wire-admin-users-page-with-auth-guard
```

**Files changed:** 0

**Build status:**
- npm install: SKIPPED
- npx tsc --noEmit: SKIPPED
- npm run build: SKIPPED
- npm run test: SKIPPED

**Code review:** No code to review — branch does not exist on `origin`. `git ls-remote` shows no `auto-claude/052-*` ref. The closest existing branch is `origin/auto-claude/037-wire-admin-credentialing-queue-page-component`, which is unrelated to this task ID.

**Reasoning:** The requested branch `auto-claude/052-wire-admin-users-page-with-auth-guard` does not exist on the `origin` remote, so there is nothing to fetch, check out, build, or audit. Recommendation is ABANDON because there is no work product to evaluate; if this branch was intended to exist, it must be created from scratch (REWRITE would also be reasonable framing, but ABANDON is the correct call for a non-existent branch).

---

## auto-claude/057-implement-patient-lab-upload-with-ocr-parsing

**Verdict:** UNRELATED
**Recommendation:** ABANDON
**Staleness:** N/A (branch not found)

**Last commit:** N/A | N/A | branch not found on origin

**Diff stats:**
```
(no diff — remote ref auto-claude/057-implement-patient-lab-upload-with-ocr-parsing does not exist)
```

**Files changed:** 0

**Build status:**
- npm install: SKIPPED
- npx tsc --noEmit: SKIPPED
- npm run build: SKIPPED
- npm run test: SKIPPED

```
$ git fetch origin auto-claude/057-implement-patient-lab-upload-with-ocr-parsing
fatal: couldn't find remote ref auto-claude/057-implement-patient-lab-upload-with-ocr-parsing

$ git ls-remote origin 'refs/heads/auto-claude/057*'
(empty)
$ git branch -a | grep -i '057'
(empty)
```

**Code review:** No files were available to review — the branch does not exist on origin. `git fetch`, `git ls-remote`, and a local branch grep all returned no results, so steps 2–11 could not be performed.

**Reasoning:** The remote ref `auto-claude/057-implement-patient-lab-upload-with-ocr-parsing` does not exist (fatal: couldn't find remote ref), so there is nothing to audit, build, test, or merge. ABANDON is the only sensible recommendation since there is no work product to integrate.

---

## auto-claude/060-comprehensive-peptide-telehealth-codebase-audit

**Verdict:** UNRELATED
**Recommendation:** ABANDON
**Staleness:** N/A (branch does not exist)

**Last commit:** N/A | N/A | branch does not exist on origin

**Diff stats:**
```
fatal: couldn't find remote ref auto-claude/060-comprehensive-peptide-telehealth-codebase-audit
```

**Files changed:** 0
- (no files — branch not found)

**Build status:**
- npm install: SKIPPED (no branch to check out)
- npx tsc --noEmit: SKIPPED
- npm run build: SKIPPED
- npm run test: SKIPPED

`git ls-remote origin 'refs/heads/auto-claude/*'` confirms no branch numbered 060 exists. The auto-claude branch sequence visible on origin jumps from 058 directly to 068, with 060 absent. No local branch by this name exists either.

**Code review:** No code to review. The branch ref does not exist on the remote, so there are no commits, diffs, or files to characterize.

**Reasoning:** The target branch is missing entirely from origin (the auto-claude numbering skips from 058 to 068), so there is nothing to audit, build, or merge. Recommendation is ABANDON because there is no work to evaluate; if this branch was expected to exist, it was either never pushed or has been deleted.
