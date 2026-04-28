---
description: Query the TRIQS Jenkins CI for build status and failure analysis (token-efficient drill-down)
---

Query the public TRIQS Jenkins at https://jenkins.flatironinstitute.org/job/TRIQS/ via `WebFetch` (no auth). Drill down only as far as needed to answer the question.

## Argument

`$ARGUMENTS`:
- empty → summarize last build on each branch + open PRs of the current repo
- `<N>` or `PR-<N>` → triqs PR #N
- branch name (`unstable`, `3.3.x`, ...) → that branch's latest build
- `<repo> <N|branch>` → other top-level Jenkins job (`nda 42`, `h5 unstable`). Default repo is `triqs`.

## URLs (triqs)

- Top-level: `.../job/TRIQS/job/triqs/`
- Branch:    `.../job/<branch>/`
- PR:        `.../view/change-requests/job/PR-<N>/` (note: PR builds live under `view/change-requests/`, not directly under `job/`)

Other flatironinstitute/TRIQS repos: `.../job/TRIQS/job/<repo>/` with the same sub-structure.

## Drill-down (stop at first useful answer)

Always pass `?tree=` to `/api/json` to limit fields.

1. **Status** — `.../api/json?tree=lastBuild[number,result,building,timestamp,duration]`. Tiny. SUCCESS → done.
2. **Stage summary** (on FAILURE) — `.../<N>/wfapi/describe`. Per-stage name/status/duration/nodeId. Find the failing stage(s).
3. **Per-stage log** — `.../<N>/execution/node/<nodeId>/wfapi/log`. Much smaller than the full console. If unavailable, fall back to (4) but narrow the WebFetch prompt to the failing stage banner.
4. **Full console** (last resort) — `.../<N>/consoleText`.

## WebFetch tips

- Demand verbatim error lines: *"Quote the last 15 lines before the first 'error' or 'FAILED' marker. Do NOT summarize."*
- When multiple stages fail with the same root cause, fully fetch one, then verify the others with a single small prompt: *"are the last error lines of stages X, Y identical to: <paste>?"* — avoids N full-log fetches.

## Output

Branch/PR + build number + result + duration. For failures: which stages failed and, per distinct root cause, the 2–5 most relevant verbatim lines. End with a recommended next action.
