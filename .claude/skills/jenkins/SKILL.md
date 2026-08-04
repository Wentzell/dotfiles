---
name: jenkins
description: Query the TRIQS Jenkins CI for build status and failure analysis via the Jenkins MCP server
disable-model-invocation: true
---

Query the TRIQS Jenkins (the `CCQ/TRIQS` folder on `jenkins-new.flatironinstitute.org`)
using the **`jenkins-fi` MCP server** tools (`mcp__jenkins-fi__*`). They are authenticated
and token-efficient — prefer them over `curl`/`WebFetch`. Drill down only as far as needed.

If `jenkins-fi` is not connected in this session (check `claude mcp list`), fall back to
anonymous `curl -sSg -m 30` against the same `.../api/json` endpoints (read-only).

## Argument

`$ARGUMENTS`:
- empty → summarize the last build on each branch of the current repo, flag any failures
- `<branch>` (`unstable`, `3.3.x`, …) → that branch's latest build
- `PR-<N>` or `<N>` → PR #N of the current repo
- `<repo> <branch|N>` → another repo (`nda unstable`, `h5 42`). Default repo is `triqs`.

## Job paths (the `jobFullName` argument)

Folder: `CCQ/TRIQS`

- Branch build: `CCQ/TRIQS/<repo>/<branch>`   (e.g. `CCQ/TRIQS/inchworm/unstable`)
- PR build:     `CCQ/TRIQS/<repo>/PR-<N>`      (PR branches are child jobs of the multibranch project)

Repos under `CCQ/TRIQS`: triqs, app4triqs, nda, h5, itertools, mpi, cthyb, ctint, ctseg,
inchworm, tprf, dft_tools, solid_dmft, maxent, hartree_fock, hubbardI,
nrgljubljana_interface, omegamaxent_interface, Nevanlinna, dftkit, modest, xca.

## Drill-down (stop at the first useful answer)

1. **Status** — `getBuild` with `tree=number,result,building,duration,timestamp`
   (omit `buildNumber` for the last build). SUCCESS → done.
2. **Failing tests** — on FAILURE, `getTestResults` with `onlyFailingTests=true`.
   Names the failing ctest(s) directly.
3. **Log search** — `searchBuildLog` with `useRegex=true` and a pattern such as
   `error:|CMake Error|fatal error|The following tests FAILED|\*\*\*(Failed|Exception|Timeout)|ERROR:`,
   plus `contextLines` for surrounding lines. Pinpoints compile/doc/link failures without
   dumping the log into context.
4. **Log paging** — `getBuildLog` with `limit`/`skip`/`cursor` when you need a specific
   region (negative `limit` reads from the end; reuse `nextCursor` to resume). Never dump
   the whole console.
5. **Flaky check** — `getFlakyFailures` when a test looks intermittent.
6. **Rerun** — `rebuildBuild` / `replayBuild` only when explicitly asked (these mutate CI).

## Output

Branch/PR + build number + result + duration. For failures: which stage/tests failed and,
per distinct root cause, the 2–5 most relevant verbatim lines. End with a recommended next action.
