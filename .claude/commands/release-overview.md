---
description: Triage a TRIQS repo's open issues and PRs into a release-readiness overview (already-addressed/outdated, must-fix-before-release, easy low-review PRs) as a local markdown document
argument-hint: [<target-version>]
effort: medium
allowed-tools: Bash, Read, Glob, Grep
---

Produce a **release-readiness overview** for the **current** repo (a TRIQS app or core-lib):
read the open issues and PRs and sort them into what helps a maintainer decide what to do before
cutting the release. The deliverable is a **local markdown document** — this skill never touches
the GitHub issue tracker (no `gh issue create`). Run from inside the repo.

Three questions to answer, per the maintainer's release checklist:
1. Which open issues are **already addressed or outdated** (can be closed)?
2. Which are **crucial to tackle before the release**?
3. Which open PRs are **simple, low-review-effort** and can just be pulled in?

## Argument

`$ARGUMENTS` (optional): the target version (for the document title/heading). Otherwise infer
from `project(... VERSION …)` and the intended bump; ask if ambiguous.

## Context

- Repo dir: !`basename "$(git rev-parse --show-toplevel)"`
- `upstream`/`origin` TRIQS remote: !`git remote -v | grep -iE '^(upstream|origin)\b' | grep -i triqs | head`
- `project(...)`: !`grep -E "^project\(" CMakeLists.txt | head -1`
- Last release tag: !`git tag --sort=-v:refname | head -3`

**Resolve the canonical GitHub repo first — never let `gh` pick.** No default `gh` repo is set,
and the TRIQS-org remote is *not always* `origin`: from a fork it's `upstream` (e.g. cthyb:
`origin`=`Wentzell/cthyb`, `upstream`=`TRIQS/cthyb`); from a direct org clone it's `origin` with
no `upstream` (e.g. h5/itertools). Pick **whichever of `upstream`/`origin` points at the TRIQS
org** (the Context probe greps for it), parse `OWNER/REPO` from its URL — stripping the
`github:` / `git@github.com:` / `https://github.com/` prefix and any `.git` — and only if neither
matches, fall back to `TRIQS/$(basename toplevel)`. **Print the resolved `OWNER/REPO` to confirm**
before any `gh` call, and pass `--repo TRIQS/<name>` everywhere.

## Phase 1 — Pull open issues & PRs

```bash
gh issue list --repo TRIQS/<name> --state open --limit 200 \
  --json number,title,labels,updatedAt,createdAt,author
gh pr list --repo TRIQS/<name> --state open --limit 200 \
  --json number,title,additions,deletions,changedFiles,reviewDecision,isDraft,updatedAt,author
```

Note the counts. **If both are empty (0 open issues and 0 PRs), report "nothing to triage" and stop
— skip Phases 2–4; do not write a near-empty document.** Otherwise, also get the last release's
date/commit so you can cross-check "addressed since":
`git show -s --format=%ci $(git tag --sort=-v:refname | head -1)`.

## Phase 2 — Classify the issues

Read each issue's title (and, for the unclear ones, fetch the body with
`gh issue view <N> --repo TRIQS/<name>`). Sort into:

- **(a) Already addressed / outdated.** Cross-check claims against the actual code/history — don't
  trust the title. An issue is likely closeable if a commit since the last release fixes it
  (`git log <last-tag>..HEAD --oneline`, grep for the symptom / referenced symbol), if it refers
  to removed/renamed API, or if it's stale (no activity in many months) and no longer reproduces.
  **Verify, then mark "likely addressed by <sha>/<PR>" or "outdated: <reason>".** Do not assert a
  fix you can't point to.
- **(b) Must-fix before release.** Correctness bugs, build/compat breakage, regressions, data-loss
  or wrong-results reports. Anything that would embarrass the release or block users on the new
  TRIQS version.
- **(c) Defer.** Feature requests, long-term refactors, questions, low-impact polish.

## Phase 3 — Classify the PRs

Surface the **easy wins** — open PRs that are cheap to review and safe to merge before the
release (same fix-vs-feature lens as `/backport-release` Phase 1):

- **Easy / low-review-effort**: small diff (low `additions+deletions`, few `changedFiles`), not a
  draft, no API break, ideally a fix/doc/test/CI change. Flag as a merge candidate.
- **Needs review / defer**: large diffs, new features, public-API additions/renames, drafts, or
  PRs with `reviewDecision` already `CHANGES_REQUESTED`.

Don't fetch full diffs for everything — use the `additions/deletions/changedFiles` from Phase 1
to rank, and only open the borderline small ones (`gh pr view <N> --repo TRIQS/<name>`).

## Phase 4 — Write the overview document

Write to your session **scratchpad** (not the repo, not a fixed `/tmp` path) as
`release-overview-<name>-<target>.md`, with three sections mirroring the questions:

```markdown
# <NAME> <target> — release overview
_open issues: N · open PRs: M · last release: <tag> (<date>)_

## Likely closeable (addressed / outdated)
- #123 <title> — addressed by <sha>/#PR  ·  or: outdated (<reason>)

## Must-fix before release
- #456 <title> — <why it blocks> · <pointer to relevant code if known>

## Easy PRs to pull in
- #789 <title> — +12/-3, 2 files, <fix/doc/…>, no API change

## Defer (for completeness)
- …
```

Keep each line to one scannable entry with the issue/PR number and the *reason* for its bucket.

## Report

- The path to the written document and the headline counts (closeable / must-fix / easy-PR).
- Show the must-fix and easy-PR sections inline so the user sees the actionable items without
  opening the file.
- **This skill produced a local document only — it did not create or modify any GitHub issue or
  PR.** Closing issues / merging PRs is the user's call.
