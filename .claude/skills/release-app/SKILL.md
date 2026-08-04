---
name: release-app
description: Orchestrate a TRIQS application or core-lib release end-to-end, sequencing the porting/merge/CI/warnings/bindings/changelog/overview steps with a human checkpoint between each phase
argument-hint: [major|compat|patch] [<target-version>]
effort: xhigh
allowed-tools: Bash, Read, Edit, Glob, Grep
disable-model-invocation: true
---

Drive a release of the **current** repo (a TRIQS app like `cthyb`/`ctseg`/`tprf`, or a core-lib
like `h5`/`itertools`/`nda`) through the standard preparation workflow, delegating each step to
the focused skill that owns it and **pausing for you between every phase**. Run from the repo root.

This is a **guided checklist, not an automated pipeline**: it never pushes, tags, or bumps the
version on its own. It holds **no state file** — it re-derives "where are we" from git each time,
so you can stop after any phase and re-invoke to resume.

## Arguments

`$ARGUMENTS`: `[major|compat|patch] [<target-version>]`
- **major** — tracks a TRIQS *major* release with API breaks → the porting script (Phase A) applies.
- **compat** — compatibility release for a new TRIQS *minor*, or a feature release with no TRIQS
  API break → skip porting.
- **patch** — `X.Y.Z+1` on a release branch → **this is `/backport-release`'s job**; hand off (see Phase 0).

If omitted, infer from the version bump and branch, and confirm in Phase 0.

## Context

- Repo: !`basename "$(git rev-parse --show-toplevel)"`
- `project(...)`: !`grep -E "^project\(" CMakeLists.txt | head -1`
- TRIQS pin: !`grep -m1 -iE "find_package\(TRIQS" CMakeLists.txt || echo "(none — core-lib, not TRIQS-dependent)"`
- Branch: !`git branch --show-current`
- Released versions (NB: ordering unreliable — `v*`/`test_*`/`rc` tags sort high; pick the last *real* release by eye): !`git tag --sort=-v:refname | head -8`
- Working tree clean: !`git status --porcelain | head`
- app4triqs remote: !`git remote -v | grep -i app4triqs | head -1 || echo "(none)"`
- Has `c++/`: !`test -d c++ && echo yes || echo "no (pure-Python)"`
- Binding style — c2py toml: !`git ls-files '*.toml' | grep -c 'python/'` · cpp2py desc: !`git ls-files '*_desc.py' | wc -l`
- TRIQS porting scripts (major app releases — each hit annotated with its checkout's branch; use the one on **unstable**, not a feature branch): !`for s in /home/wentzell/Dropbox/Coding/triqs*/porting_tools/port_to_triqs*; do [ -e "$s" ] || continue; d=${s%/porting_tools/*}; echo "$s ($(git -C "$d" branch --show-current 2>/dev/null))"; done 2>/dev/null || echo "(none found locally)"`
- Resume markers:
  - most recent app4triqs merge (tag-independent): !`git log -1 --format='%h %cs %s' --grep='Merge.*app4triqs' 2>/dev/null || echo "(no app4triqs merge in history)"`
  - ChangeLog target-version section: (checked in Phase 0: `grep -n "## Version <target>" doc/ChangeLog.md`)
  - version bumped: (checked in Phase 0 against the `project(...)` line above)

## Phase 0 — Classify, gate, and plan

**Classify the repo type** from Context (the matrix shared with `/regen-bindings` & `/merge-app4triqs`):

| Type | TRIQS pin | porting (A) | app4triqs (B) | warnings (D) | bindings (E) |
|---|---|---|---|---|---|
| **core-lib c2py** (`h5`, `nda`) | no | no | yes | yes | yes (c2py) |
| **core-lib header-only** (`itertools`) | no | no | yes | yes | no |
| **c2py app** (`cthyb`, `ctseg`, `tprf`) | yes | yes (major) | yes | yes | yes (c2py) |
| **cpp2py app** (legacy, `*_desc.py`) | yes | yes (major) | yes | yes | no (auto at build) |
| **pure-Python app** (`maxent`, `dft_tools`) | maybe | yes (major) | yes | no | no |

**Don't classify by the example app names above — they rot as apps migrate** (e.g. `tprf` moved
cpp2py→c2py mid-cycle, so a stale matrix would wrongly skip its Phase E). Determine the binding
style from the **Context** probe, which is authoritative: `python/*.toml` count > 0 ⇒ **c2py**
(Phase E applies); `*_desc.py` count > 0 ⇒ **cpp2py** (Phase E is a no-op — auto-regens at build);
has `c++/` but neither ⇒ **header-only** (no Phase E); no `c++/` ⇒ **pure-Python** (skip D and E).
`/regen-bindings` and `/merge-app4triqs` use the same probe.

Determine the **release type** (arg or infer; ask if ambiguous) and **target version**.
- **If patch** → stop and hand off: `/backport-release <target-version>` cuts a patch by
  back-porting fixes onto a release branch; this orchestrator is for the unstable→release prep flow.

**Assert the gates that apply, before doing anything:**
1. **Clean working tree** (Context) — `/merge-app4triqs` and most phases require it. Stop if dirty.
2. **Major + TRIQS-dependent repo**: `port_to_triqs<N>` must exist. It lives in whichever local
   TRIQS checkout is on the **unstable** branch — that may be `triqs` *or* `triqs_unstable`
   (don't assume `triqs`: it's often parked on a feature branch without the new script), so the
   Context probe globs `triqs*/porting_tools/`. If it's nowhere locally, it can be fetched from
   upstream unstable (see Phase A). If TRIQS core hasn't authored it at all yet, **stop** — core
   must cut the major (and author the script via `/release-changelog`) first. Core-libs skip this
   gate (they don't consume TRIQS).
3. **TRIQS-pinned repo (apps)**: a matching TRIQS `major.minor` install must be reachable
   (`CMAKE_PREFIX_PATH`/`PYTHONPATH`) or every build phase FATAL_ERRORs at configure. Verify.
4. **c2py repo**: `clair-c2py` available (`command -v clair-c2py`) for Phase E.

**Derive resume state** from git/files (no state file). The robust signals:
- **Changelog (F)**: `grep -n "## Version <target>" doc/ChangeLog.md` — present ⇒ done. Use the
  **full** `X.Y.Z` (e.g. `## Version 4.0.0`), not the two-component `X.Y` form, or the probe false-negatives.
- **Version bump**: the `project(...)` line already shows `<target>` ⇒ done (this is part of the
  manual hand-off, not a phase, but note it).
- **app4triqs merge (B)**: the **authoritative** check is whether the skeleton has commits not yet
  in HEAD — `git log --oneline <remote>/<branch> ^HEAD` (run `git remote update` first; `<branch>`
  is the app's skeleton branch — `unstable` for TRIQS+c2py apps, `python_only` for pure-Python, etc.
  — exactly `/merge-app4triqs` Step 2). A **non-empty** list ⇒ B is pending, *regardless of any prior
  merge's date*. The merge **date** alone is only a weak hint and gives **false positives** (observed:
  a 2-day-old merge with 9 still-unmerged skeleton commits). Also inspect *which ref* the Context
  marker's merge subject names: a pure-Python app whose last merge was of `…/unstable` rather than
  `…/python_only` merged the **wrong branch**, so B likely needs redoing this cycle. Don't compute
  "since the last tag" from `git tag … | head -1` — the tag ordering is unreliable (see Context note).

**Present the tailored plan** — the ordered list of phases that apply to *this* repo type and
release type, with the skipped ones called out and why, and any already-done phases from the
resume probe. **Get explicit approval before starting Phase A.**

## The phases (canonical order, checkpoint between each)

Run them in order. After each phase: print a 2–3 line status (what changed, build/test state)
and the next phase's one-line plan, then **stop and wait** for the user to say continue. Commit
points are the user's (or a `/commit` follow-up) — see each sub-skill's own "uncommitted" note.

### Phase A — Run the porting script (major releases of TRIQS-dependent repos only)
Skip for core-libs and for compat/patch releases. Run the matching script from the repo root
(no args; it rewrites files in place via regex). Use the copy from the local TRIQS checkout on
the unstable branch (Context shows where it is — could be `triqs/` or `triqs_unstable/`):
```bash
<triqs-unstable-checkout>/porting_tools/port_to_triqs<N>
```
If it isn't present locally, fetch it from upstream as the porting guide documents:
```bash
wget https://raw.githubusercontent.com/TRIQS/triqs/unstable/porting_tools/port_to_triqs<N>
chmod u+x port_to_triqs<N> && ./port_to_triqs<N>
```
(For pure-Python apps the same script rewrites the `.py` sources.)

**Guard:** the script walks the *entire* tree (`os.walk(getcwd())`, ignoring only `.git`), so a
populated build dir in the source tree makes it crash with `PermissionError` on read-only generated
files (e.g. `build/_deps/<x>-subbuild/CMakeLists.txt`). This is **not** limited to a top-level
`build/` — agents have hit `build_llvm19/`, `build_prof/`, and a *nested* `test/python/build/`.
Before running, enumerate every build dir anywhere in the tree (`find . -type d -name 'build*'`) and
handle each: a **symlink** pointing outside the tree (the usual setup, including the `build_dbg` /
`build_san` / `build_prof` / `build_genoa` variants) is skipped by `os.walk` and is fine; a **real
populated** dir must be moved aside first — move it **to a sibling directory of the repo** (e.g.
`mv build ../<repo>_build_moved`) and restore it after. Moving it to an arbitrary external path can
trip an autonomous-mode sandbox, and renaming it *within* the repo is not enough (it's still walked).

Review the diff — it should be mechanical renames only. This must be committed before Phase B,
which needs a clean tree.

### Phase B — Merge the app4triqs skeleton
`→ /merge-app4triqs`. Applies to **both** apps and core-libs (both carry `app4triqs-remote`).
Checkpoint on its report — especially any tool/framework migration it flags (clair/c2py, k8s
Jenkins, doxygen, toolchain bump).

### Phase C — Triage CI failures
`→ /ci-triage`. Check GitHub Actions + Jenkins on this branch, fix the trivial breaks, surface
the rest. Checkpoint: what was fixed, what's deferred.

### Phase D — Fix compiler & deprecation warnings (skip pure-Python)
`→ /fix-warnings`. Skip if the repo has no `c++/`.

### Phase E — Regenerate bindings (c2py repos only)
`→ /regen-bindings`, which **detects the actual binding style itself** (from the toml/desc probes —
don't pre-decide from the Phase-0 matrix, whose example names rot). It is a no-op for cpp2py
(auto-regens at build) and for header-only/pure-Python, and reports which case applies. Runs
**after** Phase D so the bindings are generated from the warning-fixed sources (avoids a double
regeneration). Review the `*.wrap.*` diff.

### Validation gate — run the full test suite (after the last code-changing phase)
Once the code-affecting phases that apply (A–E) are done, **run `ctest --test-dir <build-dir> -jN`
and report pass/fail.** No individual phase owns this — `/fix-warnings` and `/regen-bindings` both
end with "this skill does not run ctest" — so the orchestrator must. This is the test gate the
closing "build & test before pushing" reminder refers to; F (changelog) and G (overview) are
doc-only and don't need a build.

### Phase F — Prepare the changelog
`→ /release-changelog`. Curates `doc/ChangeLog.md` for the target version (it handles the
core-lib vs app phrasing, the `Run port_to_triqs<N>` / `Use latest app4triqs skeleton` bullets,
and the contributor line). Checkpoint.

### Phase G — Release-readiness overview
`→ /release-overview`. Read-only triage of open issues/PRs into a local document
(already-addressed / must-fix / easy-PR). No code dependency on A–F — safe to run anytime.

## Phase H — Hand-off

State plainly what remains **manual and not done by this orchestrator**:
- the **version bump** in `CMakeLists.txt`,
- the **commits** for the changelog and bump (the `[doc] …` / `[cmake] Bump Version …` pair),
- the **tag** and **push**.

For a patch on a release branch, `/backport-release` automates the bump+tag+push pattern; for an
unstable→release prep the bump/tag is done by hand when the release is actually cut. Point there
rather than doing it here.

## Report

- Repo type + release type + target version, and the tailored phase list with each phase marked
  **done / skipped (why) / deferred-to-user**.
- A consolidated list of what still needs the user: deferred CI items, must-fix issues from the
  overview, the manual bump/tag/push.
- Standing reminder: **build & test (`ctest`) before pushing; nothing here has been pushed or
  tagged.**
