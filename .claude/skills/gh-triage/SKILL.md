---
name: gh-triage
description: Triage the current repo's open GitHub issues and PRs — verify what is already addressed or superseded, rate severity and effort, assess PR review state — into a local markdown document with a ranked path forward
argument-hint: [--release <target-version>] [<issue-or-PR-numbers>...]
effort: high
allowed-tools: Bash, Read, Write, Glob, Grep
disable-model-invocation: true
---

Triage the open issues and PRs of the **current** repo (a TRIQS app or core-lib) and hand the
maintainer a clear, ordered path forward. For every issue: is it already addressed, how severe is
it, how much work is it. For every PR: has it been superseded, is it niche or high priority, how
far along is the review. The deliverable is a **local markdown document** — this skill is
read-only against GitHub (no `gh issue|pr edit/close/comment`). Run from inside the repo.

## Arguments

`$ARGUMENTS` (all optional):
- `--release <ver>`: release framing — document title, a "Must-fix before <ver>" section, and the
  "addressed since last release" cross-check. Without it, triage against the dev-branch tip.
- `<numbers>...`: restrict the triage to these issue/PR numbers (deep dive). Default: all open.

## Context

- Repo dir: !`basename "$(git rev-parse --show-toplevel)"`
- `upstream`/`origin` TRIQS remote: !`git remote -v | grep -iE '^(upstream|origin)\b' | grep -i triqs | head`
- `project(...)`: !`grep -E "^project\(" CMakeLists.txt | head -1`
- Branch / tip: !`git branch --show-current` — !`git log -1 --oneline`
- Last release tags: !`git tag --sort=-v:refname | grep -E '^v?[0-9]' | head -3`

**Resolve the canonical GitHub repo first — never let `gh` pick.** No default `gh` repo is set,
and the TRIQS-org remote is *not always* `origin`: from a fork it's `upstream` (e.g. cthyb:
`origin`=`Wentzell/cthyb`, `upstream`=`TRIQS/cthyb`); from a direct org clone it's `origin` with
no `upstream` (e.g. h5/itertools). Pick **whichever of `upstream`/`origin` points at the TRIQS
org** (the Context probe greps for it), parse `OWNER/REPO` from its URL — stripping the
`github:` / `git@github.com:` / `https://github.com/` prefix and any `.git` — and only if neither
matches, fall back to `TRIQS/$(basename toplevel)`. **Print the resolved `OWNER/REPO` to confirm**
before any `gh` call (print and proceed — no confirmation pause), and pass `--repo OWNER/REPO`
everywhere.

The **dev branch** is `unstable` (fall back to the current branch if it doesn't exist). All
"already landed?" checks are against its tip — or, with `--release`, against
`<last-tag>..<dev-tip>` (`git show -s --format=%ci <last-tag>` gives the release date).

## Phase 1 — Fetch

```bash
gh issue list --repo OWNER/REPO --state open --limit 200 \
  --json number,title,labels,createdAt,updatedAt,author,comments,body
gh pr list --repo OWNER/REPO --state open --limit 200 \
  --json number,title,author,isDraft,createdAt,updatedAt,baseRefName,headRefName,additions,deletions,changedFiles,reviewDecision,mergeable,mergeStateStatus,statusCheckRollup,body
gh pr list --repo OWNER/REPO --state merged --limit 100 --json number,title,mergedAt,mergeCommit
```

Note the counts. **If there are 0 open issues and 0 open PRs, report "nothing to triage" and stop**
— do not write a near-empty document. If numbers were given as arguments, keep only those items.

Field shapes worth knowing: `comments` on issues is the full comment array (bodies included) —
do not re-fetch them; `mergeCommit` is an object (`.mergeCommit.oid`); `statusCheckRollup` mixes
check runs and status contexts, so summarize CI with `map(.conclusion // .state)`.

## Phase 2 — Issues

For each issue read the body and the comments from the Phase 1 JSON. Decide three things:

1. **Status.** Cross-check the claim against code and history — don't trust the title.
   - `addressed by <sha>/#PR`: a commit on the dev branch fixes it (`git log <base>..HEAD --oneline`
     grepped for the symptom/symbol, `git log -S<symbol>`, merged PRs whose title/body mention `#N`).
     Direct pushes without a PR are common in TRIQS repos — `git log -S` is the primary check, the
     merged-PR list only a supplement.
   - `outdated: <reason>`: refers to removed/renamed API (`git grep` finds nothing), or an
     environment that is no longer supported.
   - `stale-waiting`: the last comment is a maintainer question the reporter never answered.
   - `open`: still valid.
   **Never assert a fix you can't point to** — a sha, a PR number, or a file:line.
2. **Severity** (open items only):
   - `critical` — wrong results, data loss/corruption, crash on a core path, build break on a
     supported toolchain.
   - `high` — incorrect behaviour with a workaround, regression, breaks a downstream TRIQS project.
   - `medium` — missing capability users actually hit, misleading error, doc gap that causes misuse.
   - `low` — polish, cosmetic, question, nice-to-have.
3. **Effort** (open items only). Locate the code first — `git grep` the symbols named in the
   issue and read the relevant function(s) — then judge:
   - `S` — localized change in one or two functions, obvious test, under an hour.
   - `M` — several files, or a new test / `.ref.h5`, about half a day.
   - `L` — design decision, public-API addition/change, multi-component, or needs discussion first.
   Record the file(s) that would change; that pointer is what makes the estimate credible.

## Phase 3 — Pull requests

Rank by `additions+deletions` / `changedFiles` first; fetch `gh pr diff N --repo OWNER/REPO`
only for the ones that need a supersession check or are borderline. Never `git fetch` PR refs
into the local tree — stay read-only locally.

For each PR:

1. **Status.**
   - `superseded by <sha>/#PR`: the same change already landed in another form — grep the
     symbols/files from the diff with `git log -S` / `git grep` on the dev branch (direct commits,
     not only merged PRs). Say `partly superseded` when only part of the diff has landed.
   - `conflicting`: `mergeable == CONFLICTING` / `mergeStateStatus == DIRTY`.
   - `stale (since <date>)`: no commit, review, or comment in > 6 months; drafts included.
   - `current`.
2. **Priority.** Does it close a `critical`/`high` issue from Phase 2 (`Fixes #N` in the body, or
   an issue referencing the PR)? Is the benefit ecosystem-wide (nda/triqs/apps) or does it serve a
   single downstream use case? Label `high-priority` / `useful` / `niche`, one clause of reason.
3. **Review state.** From `gh pr view N --repo OWNER/REPO --json commits,reviews,comments` and,
   for thread resolution (REST has no resolved flag), one GraphQL call:
   ```bash
   gh api graphql -f query='{ repository(owner:"OWNER", name:"REPO") { pullRequest(number: N) {
     reviewThreads(first: 100) { nodes { isResolved comments(first:1) { nodes { path body } } } } } } }'
   ```
   - review rounds so far; latest decision (`APPROVED` / `CHANGES_REQUESTED` / none);
   - unresolved threads; whether commits were pushed **after** the last review (ball is with the
     reviewer) or the last review is newer than the last commit (ball is with the author);
   - CI from `statusCheckRollup` (pass / fail / none).
   Summarize as `unreviewed` / `awaiting-author` / `awaiting-reviewer` / `approved`, plus `draft`
   when `isDraft`.
4. **Effort to land** (`S`/`M`/`L`): review + rebase + finish, from diff size, conflict state, and
   how much review feedback is still open. When rebasing and finishing differ, write both, e.g.
   `rebase S / finish L`.

## Phase 4 — Path forward

One ordered action list covering every item. Ordering:
1. zero-cost cleanup — `close` addressed/outdated issues, `close` superseded PRs;
2. `critical` + `S`, then `high` + `S`/`M` fixes;
3. PRs that are `approved` or `awaiting-reviewer` with small effort — `merge` / `review`;
4. `rebase-and-merge` / `ping-author` for conflicting or awaiting-author PRs worth keeping;
5. the rest by severity descending, effort ascending;
6. `L` design items last, each with one line naming the decision that has to be made.

Actions are one of: `close`, `merge`, `review`, `rebase-and-merge`, `ping-author`,
`fix (S|M|L)`, `design-discussion`, `defer`.

## Phase 5 — Write the document

Write to the session **scratchpad** (not the repo, not a fixed `/tmp` path) as
`gh-triage-<name>.md`, or `gh-triage-<name>-<ver>.md` with `--release`:

```markdown
# <NAME> — issue & PR triage[ for <ver>]
_open issues: N · open PRs: M · dev tip: <sha>[ · last release: <tag> (<date>)]_

## Path forward
1. close #27 — <one-line reason with pointer>
2. merge #32 — approved, +12/-3, CI green
3. fix #39 (high, S) — <file>: <what to change>
…

## Issues
| # | title | status | severity | effort | where | note |
|---|---|---|---|---|---|---|

## Pull requests
| # | title | status | priority | review state | CI | effort | note |
|---|---|---|---|---|---|---|---|

## Closeable / superseded
- #N <title> — addressed by <sha>/#PR  ·  or: outdated (<reason>)   (write "- none" if empty)

## Must-fix before <ver>          ← only with --release
- #N <title> — <why it blocks the release>
```

One scannable row per item. Every status, severity, or effort claim carries its pointer (sha, PR,
file:line) in the `where`/`note` column.

## Report

- Path to the document and headline counts: closeable / critical+high / PRs ready to merge
  (`approved` and not `conflicting`).
- Show the **Path forward** section inline so the user sees the actions without opening the file.
- **This skill produced a local document only — nothing on GitHub was changed.** Closing, merging,
  labeling, and commenting are the user's call.
