---
description: Back-port fixes from a development branch to a release branch and cut a patch release
argument-hint: <new-version> [<dev-branch>]
effort: large
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

Cut a patch release on the current release branch by back-porting eligible commits from a development branch. Works for TRIQS core and any `../triqs_apps/*` / `../triqs_libs/*` project — they share the layout: `CMakeLists.txt` with `project(<NAME> VERSION X.Y.Z ...)`, `doc/ChangeLog.md`, `c++/` + `python/` + `test/`.

## Arguments

- `<new-version>` (required) — e.g. `3.3.3`. Must be exactly one patch above the version in `CMakeLists.txt`.
- `<dev-branch>` (optional, default `unstable`).

## Context

- Repo: !`basename "$(git rev-parse --show-toplevel)"`
- `project(...)`: !`grep -E "^project\(" CMakeLists.txt | head -1`
- Release branch: !`git branch --show-current`
- Latest tag: !`git describe --tags --abbrev=0 2>/dev/null || echo "(no tag)"`
- Tag style: !`git tag --sort=-v:refname | head -3`
- Tip: !`git log -1 --oneline`
- Working tree: !`git status --porcelain`
- Remotes: !`git remote -v | awk 'NR<=4'`

## Phase 1: Identify back-portable commits

Stop if the working tree isn't clean (see Context). Fetch the dev branch if stale.

```bash
git log --reverse --no-merges --format="%h %s" $(git merge-base HEAD <dev-branch>)..<dev-branch>
```

**Back-port**: bug fixes, doc/typo fixes, test fixes (assertions that weren't asserting), build/CI fixes, dep-compatibility patches.
**Skip**: new features (incl. small ones like new constructors/operators/accessors/optional args), public-API additions/renames/removals, behavioral changes that aren't strict fixes, refactors not motivated by a bug.

**Hidden-coupling gotcha** — a fix may compile-depend on an earlier dev-only refactor. Common in this ecosystem: c2py+clair binding port, `mpi::monitor` API rename (`request_emergency_stop`/`emergency_occured` → `report_local_event`/`event_on_any_rank`), nda/h5/itertools API drift. **Adapt** the fix to the release-branch API rather than dragging in the prerequisite — only defer the fix if adaptation is unreasonable.

Present a categorized table with one-line rationale per commit. **Get explicit user approval before cherry-picking.**

## Phase 2: Cherry-pick onto a backport branch

```bash
git switch -c backport-<new-version>
git cherry-pick <sha>   # in order, smallest/safest first
```

On conflict:
1. Cosmetic only (autoformatter / unrelated reflow) → `--abort`, re-apply the substantive change as a fresh commit, preserve authorship with `--author=`.
2. Substantive but small → resolve, continue.
3. Pulls in a chain of prerequisites → drop, record as "deferred — depends on <X>".

Drop commits mid-rebase non-interactively:
```bash
GIT_SEQUENCE_EDITOR="sed -i '/<sha1>\|<sha2>/d'" git rebase -i <base>
```

## Phase 3: Build, fix in-tree warnings, test

Configure into a clean build dir (e.g. `~/builds/<repo>_<release>`); if the cached compiler is stale, wipe the dir and reconfigure rather than patching the cache. Apps need a matching TRIQS install on `CMAKE_PREFIX_PATH` / `LD_LIBRARY_PATH` / `PYTHONPATH`.

Fix in-tree compiler warnings via direct edits (do not back-port a "fix warnings" commit unless asked). Dep warnings are out of scope — note them in the final report. All `ctest -j 16` tests must pass before continuing.

## Phase 4: Update `doc/ChangeLog.md`

Insert a `## Version <new-version>` section **above** the previous one. Read the prior 2-3 patch entries first and match their wording, opening sentence, and component-subsection headings exactly — these vary per project. Contributor line comes from Phase 5.

## Phase 5: Verify contributors

```bash
git log --format="%an%n%(trailers:key=Co-Authored-By,valueonly)" \
  $(git describe --tags --abbrev=0)..HEAD | sed '/^$/d' | sort -u
```

Include co-authors and authors of any post-tag housekeeping commits on the release branch. **Exclude `Claude` / `claude@anthropic.com` even if it appears as `Co-Authored-By`.** Sort alphabetically by first name (project convention).

## Phase 6: Bump version

Edit `CMakeLists.txt`: `project(<NAME> VERSION <new-version> LANGUAGES CXX)`. Check for other authoritative copies of the version:

```bash
git grep -nF "<OLD_VERSION>"
```

Most hits (`__init__.py`, `Doxyfile`, `doc/conf.py`, `version.py`) are CMake-generated — skip those.

Two commits, matching the project's prior wording (`git log --oneline`):
- `[cmake] Bump Version number to <new-version>`
- `[doc] Update changelog for <new-version>`

## Phase 7: Merge, tag, push

Confirm with the user before mutating the release branch.

```bash
git switch <release-branch>
git merge --ff-only backport-<new-version>
git branch -d backport-<new-version>
```

Annotated tag — match the prior tag's name (`<new-version>` or `v<new-version>`) and message format (`git show <prior-tag>`):
```bash
git tag -a <new-version> -m "<Project> Version <new-version>"
```

**Push only on explicit user request.** Verify the remote name first (`git remote -v` — typically `upstream` for TRIQS-org, but not always):
```bash
git push <remote> <new-version>
git push <remote> <release-branch>   # confirm separately
```

## Report

- N back-ported / N considered / N deferred (with reason)
- In-tree warnings fixed (file:line)
- Remaining dep warnings (out of scope)
- Test results
- Tag created / pushed (yes/no)
