---
description: Gather open CI failures across GitHub Actions and TRIQS Jenkins for the current repo, categorize the root causes, fix the trivial in-tree ones, and report the rest
argument-hint: [<branch-or-PR>]
effort: high
allowed-tools: Bash, Read, Edit, Glob, Grep
---

Find out why CI is red for the **current** repo and fix what's cheaply fixable. These projects
run **two** CIs: GitHub Actions (`.github/workflows/build.yml`) and TRIQS Jenkins
(`Jenkinsfile` or `jenkins/Jenkinsfile`). This skill checks both, de-duplicates a shared root
cause across legs, fixes the trivial in-tree breakages, and hands the judgment calls back to you.
Run from inside the repo.

## Argument

`$ARGUMENTS` (optional): the branch or `PR-<N>` to triage. Default: the current branch.

## Context

- Repo dir: !`basename "$(git rev-parse --show-toplevel)"`
- TRIQS-org remote (upstream *or* origin): !`git remote -v | grep -iE '^(upstream|origin)\b' | grep -i triqs | head`
- Branch: !`git branch --show-current`
- Jenkins config present: !`ls jenkins/Jenkinsfile Jenkinsfile 2>/dev/null || echo "(no Jenkinsfile — maybe no Jenkins job)"`
- GH workflows: !`ls .github/workflows/*.yml 2>/dev/null`

**Resolve the canonical GitHub repo first — never let `gh` pick.** No default `gh` repo is set,
and the TRIQS-org remote is *not always* `origin`: when you work from a fork it's `upstream`
(e.g. cthyb: `origin`=`Wentzell/cthyb`, `upstream`=`TRIQS/cthyb`); when you cloned the org repo
directly it's `origin` and there's no `upstream` (e.g. h5/itertools). So pick **whichever of
`upstream`/`origin` points at the TRIQS org** (the Context probe greps for it), parse `OWNER/REPO`
from its URL — stripping the `github:` / `git@github.com:` / `https://github.com/` prefix and any
`.git` — and only if neither matches, fall back to `TRIQS/$(basename toplevel)`. **Print the
resolved `OWNER/REPO` to confirm** before any `gh` call, and pass it as `--repo TRIQS/<name>`
everywhere.

## Phase 1 — GitHub Actions failures

```bash
gh run list --repo TRIQS/<name> --branch <branch> --status failure --limit 10 \
  --json databaseId,headBranch,workflowName,conclusion,createdAt,event
```

For the latest relevant failed run, get the failed-job logs — but note `--log-failed` returns
the **entire** failed-job log (runner provisioning included; easily thousands of lines, all
tab-prefixed with `<job>\t<step>\t<ts>`). **Do not read it raw — grep it for the error markers**:

```bash
gh run view <databaseId> --repo TRIQS/<name> --log-failed 2>&1 \
  | grep -iE 'error:|fatal error|FAILED|CMake Error|undefined reference|No such file|ninja: build stopped'
```

This collapses an ~9000-line log to the handful of lines that matter and, because the job column
is preserved, shows the matrix leg each error came from (`ubuntu-24.04 clang++-20`,
`ubuntu-24.04 g++-14`, `macos-15 clang++`, `macos-15 g++-15`). Pull a few lines of surrounding
context for the borderline ones. Record the **verbatim** error, not a paraphrase. (One CI break
typically lights up *all* legs with the same line — that's one root cause, not four.)

## Phase 2 — Jenkins failures

Only if a Jenkins job exists (Context showed a `Jenkinsfile`). **Reuse the `/jenkins` skill** —
do not re-implement its URL scheme or drill-down. Invoke `/jenkins <branch>` (or
`/jenkins <name> <branch>` for a non-`triqs` repo) to get the failing stages and their verbatim
error lines via its status → `wfapi/describe` → per-stage-log path. If there's no Jenkins job
for this repo, say so and skip.

## Phase 3 — Categorize root causes

Collapse the failures into **distinct root causes** (one CI break often lights up several matrix
legs / both CIs with the *same* error — de-dup them; confirm sameness by comparing the verbatim
error lines, the `/jenkins` skill's trick). Bucket each:

- **(a) Trivial / in-tree-fixable** — a deprecation now erroring on a newer compiler, a missing
  `#include`, a ref-file (`*.ref.h5`) drift, a `-W…` that one leg promotes, a typo. Fixable here.
- **(b) Toolchain / API-drift** — needs judgment: a TRIQS/nda/h5 API moved, a libclang/compiler
  version mismatch, a dependency bump. Diagnose and propose, but don't blindly patch.
- **(c) Infra / flaky** — runner timeout, network, ccache, transient. Report only; not a code fix.

## Phase 4 — Fix the trivial ones

For category (a) only: make the surgical in-tree edit, then **rebuild the affected target
locally to confirm** (configure into a build dir if needed; matching TRIQS install required for
apps; never `rm -rf build`, only `build/*`). Reproduce the failing leg's condition where you can
(e.g. the stricter compiler). Do **not** touch generated `*.wrap.*` files. Leave (b)/(c) for the
user with a concrete recommendation each.

## Report

A table, one row per **distinct root cause**:

| root cause | CI / leg(s) affected | category | action |
|---|---|---|---|

…where *action* is either the fix (`file:line` + one line) or "deferred — <why / recommendation>".
End with: which CIs/branches you checked and the resolved `TRIQS/<name>`; and the standing
reminder — **fixes are uncommitted; build & test before pushing, push is yours.**
