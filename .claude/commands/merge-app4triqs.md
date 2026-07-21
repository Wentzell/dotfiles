---
description: Merge upstream app4triqs skeleton changes into the current TRIQS app, resolving conflicts and creating a merge commit
argument-hint: [appname]
effort: high
allowed-tools: Bash, Read, Edit, Glob, Grep
---

Pull generic improvements from the [app4triqs](https://github.com/triqs/app4triqs) skeleton
into the **current** TRIQS application repo, resolving conflicts with judgment and leaving a
clean two-parent merge commit. Run this from inside the target app's repo. This follows the
"Merging app4triqs skeleton updates" procedure in app4triqs's `README.md`, but resolves
conflicts intelligently instead of blanket `-X ours`.

**The skeleton has several branches — `unstable` is rarely the right one.** Pick the branch
that matches the app (Step 0): `notriqs`/`cpp_only_notriqs` for apps that have dropped the
TRIQS dependency, `unstable` only for classic TRIQS+cpp2py apps. Merging `unstable` into a
no-TRIQS app silently drags the `find_package(TRIQS)` dependency back in — exactly what the app
removed.

The end result should look like the existing history, e.g.
`Merge remote-tracking branch 'app4triqs-remote/notriqs' into unstable`.

## Argument

`$ARGUMENTS` (optional): the application name (used for string normalization in Step 5). If
omitted, derive it (see Step 0).

## Step 0 — Preflight & classify the app

- `git rev-parse --is-inside-work-tree` — confirm we're in a git repo. Abort otherwise.
- `git status --porcelain` — **tracked** files must be clean: if any tracked file is modified
  or staged, stop and tell the user to commit or stash first. **Untracked** files (`??`) do
  *not* block the merge, but they are a trap — `git add -A` later (Steps 5/6) would sweep the
  user's scratch files into the merge commit. Note any now and, if present, stage only resolved
  paths explicitly throughout (never blanket `git add -A`).
- Record `BRANCH=$(git rev-parse --abbrev-ref HEAD)` and `BASE=$(git rev-parse HEAD)` for the
  final summary/diff.
- Determine **appname**: use `$ARGUMENTS` if given; otherwise infer from the single
  app-specific dir under `c++/` (e.g. `c++/cthyb` → `cthyb`) or `python/`, falling back to
  the repo directory name. Confirm the chosen name in your report.
- **Classify the app — this single fact drives the branch choice (Step 0b) and most conflict
  resolution.** Two orthogonal axes: (i) does it compile C++? (ii) does it depend on TRIQS?
  - C++ sources in `c++/<appname>/` **and** `add_subdirectory(c++` in the root `CMakeLists.txt`
    → compiles C++. Else (only `.py` under `python/`) → **pure-Python app** (e.g. hartree_fock,
    maxent, solid_dmft).
  - `find_package(TRIQS` present in the root `CMakeLists.txt` → **TRIQS-dependent**; absent →
    **no-TRIQS** (the core-libs mpi/itertools/h5/nda dropped it).

  Then place the app in one of these classes (it determines the Python policy below):
  - **pure-Python** — reject *all* C++/binding scaffolding; keep the app's slimmed version.
  - **C++ + bindings** — compiles C++ *and* generates Python bindings (has `module.cpp` /
    `module.toml` / `c2py_add_module` / a `python/<pkg>/` module). Adopt the clair/c2py
    machinery.
  - **C++ + converter-headers-only** (e.g. **nda**) — compiles C++, keeps a `PythonSupport`
    option and ships c2py *converter headers* (e.g. `c++/<app>/c2py/*.hpp`, `python/<pkg>/*.hpp`)
    but does **not** generate bindings and does **not** depend on clair-c2py. **Keep**
    `PythonSupport` and the converter headers/package; **reject** binding-generation machinery
    (clair CI regen, `Update_Python_Bindings`, `module.cpp`/`*.wrap.*`). Do *not* strip
    `PythonSupport` the way you would for a C++-only app.
  - **C++-only** (e.g. **mpi**, **itertools**) — no Python at all; strip `PythonSupport`
    entirely.

  This matters because the merge base is the old "Track app4triqs skeleton" squash, so a
  skeleton that has since gained C++/binding machinery (clair/c2py port, doxygen, sanitizer
  builds) will replay *all* of it as conflicts. Record the classification and apply the matching
  policy in Step 4.

## Step 0b — Pick the skeleton branch to merge

The skeleton maintains a branch per class. Choosing wrong silently re-adds (or strips) a whole
dependency, so set `BR=<branch>` here and use it in Steps 1b/2/3:

- **TRIQS-dependent** app → `unstable` (the classic skeleton, with `find_package(TRIQS)` +
  cpp2py).
- **no-TRIQS, C++ + bindings** → `notriqs` (TRIQS removed, clair/c2py binding generation kept).
- **no-TRIQS, C++ converter-headers-only or C++-only** → `cpp_only_notriqs` (TRIQS + Python
  module generation both stripped). **nda, mpi, itertools, h5 all use this.**
- **pure-Python** → `python_only` / `python_only_pip`.

Confirm the branch exists (`git branch -r --list '*/<branch>'` after Step 1's fetch) and state
your choice in the report. When the app keeps a feature the chosen branch *strips* (e.g.
`cpp_only_notriqs` strips `PythonSupport`, but a converter-headers-only app keeps it), expect
Step 4 to override those skeleton removals — see Step 4b's "strip-out" warning.

## Step 1 — Locate (or create) the app4triqs remote, refresh everything

- `git remote -v`. Find the remote whose URL contains `app4triqs`. Normally this is
  `app4triqs-remote`; older apps may use `app4triqs_remote` or `app4triqs` — use whatever
  exists. Call it `<remote>`.
- If none exists, create the canonical one:
  `git remote add app4triqs-remote https://github.com/triqs/app4triqs` and use that.
- **Update all remotes** so both the skeleton and the app's own remotes are current:
  `git remote update --prune`.

## Step 1b — Ensure the local branch is up to date with its own upstream

We must merge skeleton changes into a current branch, not a stale one.

- `git rev-parse --abbrev-ref --symbolic-full-name @{u}` — find the branch's tracking remote
  (e.g. `origin/unstable`, `upstream/unstable`). If it has **no** upstream, note that and
  skip the behind/ahead check.
- `git rev-list --left-right --count @{u}...HEAD` — gives `<behind>  <ahead>`.
  - **Behind > 0**: the local branch trails its remote. **Stop** and tell the user to bring
    it up to date first (`git pull --ff-only`), so the merge lands on top of current work.
    Do not auto-pull — that's a state change they should drive.
  - **Behind = 0**: proceed (being ahead of the remote is fine).

## Step 2 — Summarize incoming changes (before touching anything)

- `git log --oneline <remote>/$BR ^HEAD` — skeleton commits not yet in this app (`$BR` from
  Step 0b).
- `git diff --stat HEAD...<remote>/$BR` — preview the file footprint. **Caveat:** if a *prior*
  cycle hand-applied skeleton changes (cherry-picked or re-typed them) instead of merging, this
  diff **overstates** the real surface — it still shows additions/deletions the app already applied,
  so it can look like thousands of lines when little is genuinely outstanding. The `git log …
  ^HEAD` commit count above is the authoritative measure of what's left, **not** the diff stat.
- If there is nothing to merge, report **"already up to date"** and stop.
- **Scan for tool/framework migrations** — the rare, high-impact changes that need the
  deliberate handling in Step 4c. Flag any of these in the incoming log/footprint and tell
  the user up front which apply:
  - new `jenkins/Jenkinsfile` + `jenkins/Dockerfile` (k8s Jenkins migration),
  - `module.toml` / `c2py_add_module` / a `clair` CI step (cpp2py → clair/c2py bindings),
  - a new `doc/doxygen/**` tree (doxygen C++ API docs),
  - a toolchain bump in `build.yml` (e.g. `clang`→`clang-20` + `libclang-*-dev`).

## Step 3 — Merge

```bash
git merge <remote>/$BR -m "Merge remote-tracking branch '<remote>/$BR' into $BRANCH"
```

No `-X ours` — let conflicts surface so they can be resolved on their merits. **Do not use
the README's `-X ours`**: it auto-resolves *every* conflict in favor of the app and so
silently discards the generic skeleton improvements that are the whole point of the merge
(CI workflows, sphinx config, new `jenkins/` setup, etc.).

## Step 4a — Structural-conflict triage (do this first)

`git status` groups unmerged paths. Clear the mechanical ones before reading any content
conflict — for a **pure-Python app** these are almost all "the skeleton is adding C++/binding
machinery this app deleted," and the answer is uniformly *reject it*:

- **`deleted by us`** (skeleton modified a file this app removed): keep deleted →
  `git rm <file>`. Covers `c++/app4triqs/*`, the example `test/python/Basic.py`, etc.
- **`added by them`** under `c++/**`, `python/**/module.cpp`, `**/module.toml`,
  `**/*.wrap.{cxx,hxx}`, `doc/doxygen/**`: c2py/clair binding scaffolding and C++ API docs.
  Pure-Python app → `git rm` them all. C++/hybrid app → keep and let Step 5 normalize names.
- **`both added` / rename-location conflicts** (skeleton added a file inside a directory this
  app renamed, e.g. `python/app4triqs/module.cpp` → `python/<pkg>/`): same rule — reject for
  pure-Python, keep+normalize for C++/hybrid.
- Whole-file decisions are fastest via `git checkout --ours <file>` / `--theirs <file>` then
  `git add` — use `--ours` for any build file whose C++ sections this app deleted (e.g.
  `deps/CMakeLists.txt`, `doc/CMakeLists.txt`, `doc/documentation.rst`).

## Step 4b — Content conflicts (`both modified`) with judgment

For the remaining real conflicts, read each one:

- **CI & build infrastructure** (`.github/workflows/build.yml`, `Jenkinsfile`,
  `jenkins/Jenkinsfile`, `.gitignore`, `share/cmake/*`, root `CMakeLists.txt` plumbing,
  `test/python/CMakeLists.txt`): **prefer the skeleton's new version**, but preserve
  app-specific bits — project name & version, Jenkins notification email, extra deps/test
  targets, custom steps. **Pure-Python apps:** also drop C++-only CI knobs the skeleton
  re-introduces — set `regenPlatforms = []` (no bindings to regenerate) and remove the
  `sanitize` platform from `dockerPlatforms` (no C++ to sanitize), matching what the app
  already does.
- **App identity** — `appname` vs `app4triqs`: **keep the app's name**.
- **App source / tests / docs content** under `c++/<appname>/`, `python/<appname>/`, `test/`,
  `doc/*.rst`: **keep the app's version**; skeleton example content is not wanted.
- **Watch the auto-merged hunks, not just the conflicts.** A clean auto-merge can still pull in
  references to CMake targets this app doesn't define — not only the C++ ones a **pure-Python** app
  lacks (`${PROJECT_NAME}_c`, `${PROJECT_NAME}_warnings`, `${PROJECT_NAME}_python_modules`,
  `add_subdirectory(c++…)`), but also **skeleton-introduced targets a C++ app may still not define**
  (e.g. an `add_dependencies(… ${PROJECT_NAME}_docs_example_output)` line, when the app dropped
  example-output generation — taking the skeleton side then references an undefined target and breaks
  the doc build). Before adopting any skeleton `add_dependencies(… <target>)`, confirm the app
  actually defines `<target>`. When in doubt, compare a resolved build file against
  `git show HEAD:<file>` (the app's pre-merge version) — Step 5b catches leaks too.
- **The reverse trap: auto-merges that *strip* a feature the app keeps.** When the chosen branch
  removed something the app retains (e.g. `cpp_only_notriqs` strips `PythonSupport`, but a
  converter-headers-only app like nda keeps it), git replays that removal as a *clean* deletion —
  no conflict marker — silently gutting the app's wiring. Real example: the PythonSupport block
  in `share/CMakeLists.txt` and the `@EXPORT_PYTHON_PATH@` / `@MODFILE_PYTHON_PATH@` placeholders
  in `share/*vars.sh.in` / `share/*.modulefile.in` vanished from nda. After resolving, `git diff
  HEAD -- share/CMakeLists.txt share/*.in` and confirm nothing the app needs was deleted; restore
  it if so (using the *current* variable names, e.g. `PYTHON_LIB_DEST_ROOT`, not a stale
  `CPP2PY_PYTHON_LIB_DEST_ROOT`).

After resolving each file: `git add <file>` (the specific path — not `git add -A` if untracked
files are present; see Step 0). **Do not commit yet.**

## Step 4c — Tool/framework migrations (handle each as its own sub-task)

Once in a while the skeleton doesn't just *evolve* a file — it **swaps a whole tool or
framework**. These are rare, infrequent, and structurally different from ordinary conflicts:
line-by-line merging is the *wrong* mental model, because a migration typically (a) adds a
**replacement** file/dir that supersedes an existing one, and/or (b) introduces a whole
toolchain that only makes sense for one class of app. The two failure modes are **silent loss**
(an app customization in the superseded file vanishes because git never flagged it) and
**silent leakage** (a C++-only toolchain lands in a pure-Python app). So when Step 2 flagged a
migration, stop and tackle it deliberately — per migration, with the user in the loop — rather
than letting it dissolve into the conflict pile.

General procedure for **any** migration:
1. **Does it even apply to this app?** A migration built for C++/binding apps (clair/c2py,
   doxygen, sanitizer/regen CI) is **rejected wholesale** on a pure-Python app (Step 0
   classification). Say so and skip the rest for that migration.
2. **If it replaces an existing file/dir, diff old → new and port app customizations.** Run
   `git show HEAD:<old-file>` against the incoming new file and account for *every*
   app-specific line: which are carried over, which are intentional framework changes to keep,
   and which would be **lost**. Report the lost ones explicitly.
3. **If a customization has no slot in the new framework, do not invent one** — flag it for the
   user (it may live in a Jenkins shared library, a central config, etc. you can't see).

Known migrations and how they land:

- **cpp2py → clair/c2py** (Python-binding generation). Touches `deps/CMakeLists.txt`
  (`Cpp2Py`→`c2py`), `python/**/CMakeLists.txt` (`add_cpp2py_module`→`c2py_add_module`), adds
  `module.cpp`/`module.toml`/`*.wrap.{cxx,hxx}`, `set(CMAKE_CXX_SCAN_FOR_MODULES OFF)`, a
  "Build & Install clair" CI step, `regenPlatforms`, and a `libclang`/`llvm-*-dev`/
  `python3-clang*` toolchain. **C++ + bindings app:** adopt it (keep+normalize the new files).
  **Pure-Python app:** reject *all* of it — there are no bindings to generate (see Step 5b's
  CI grep). **C++ converter-headers-only app (nda):** reject the binding-*generation* parts
  (clair CI regen, `regenPlatforms`, `Update_Python_Bindings`, `module.cpp`/`*.wrap.*`) but
  **keep** `set(CMAKE_CXX_SCAN_FOR_MODULES OFF)` and `PythonSupport` — the app still compiles
  C++ and clair-c2py may consume its `compile_commands.json`, which the modmap flags break.
  **C++-only app (mpi/itertools):** reject all of it like pure-Python. Note: pre-existing clair
  regen machinery already in the app's `jenkins/Jenkinsfile` is *not* a merge conflict — flag it
  for the user rather than silently stripping it.

- **k8s Jenkins framework** (top-level `Jenkinsfile` → new `jenkins/Jenkinsfile` +
  `jenkins/Dockerfile`). The new file is a **replacement**, so git won't conflict it against the
  old top-level `Jenkinsfile` — you must diff them by hand. Intentional framework changes to
  **keep** (do not port the old file's values over these): `triqsProject` path
  (`/TRIQS/...`→`/CCQ/TRIQS/...`), `keepInstall = false`, `installBase`. **Email: follow the
  app4triqs `jenkins/Jenkinsfile` verbatim** — the new Jenkins handles failure-notification
  recipients centrally, so keep the parameterless `emailFailure()` and do **not** port the old
  inline `emailext(... to: '<user>@...')` recipient. App customizations that **do** need porting
  from the old file: any extra build deps, custom `cmake -D…` flags, and doc/packaging
  publishing tweaks. Also apply the pure-Python CI edits (`regenPlatforms = []`, drop
  `sanitize`) here too.

## Step 5 — Normalize naming

The merge may have introduced `app4triqs` / `APP4TRIQS` strings or `app4triqs*` paths. **Do not
rely on `./share/replace_and_rename.py`** here: its directory renames are a no-op on every merge
after the initial app setup, and it reads every file as UTF-8 so it *crashes* on the first
binary file without an excluded extension. Normalize surgically with git instead:

```bash
# residual strings (the two share/ scripts legitimately contain "app4triqs" — exclude them)
git grep -lI -e app4triqs -e APP4TRIQS -- . \
  ':(exclude)share/replace_and_rename.py' ':(exclude)share/squash_history.sh'
# any files named app4triqs*
git ls-files '*app4triqs*'
```

Fix each hit by hand (`appname` for `app4triqs`, `APPNAME` for `APP4TRIQS`; `git mv` any
misnamed file), then stage the fixed paths (`git add <path>…`; **only** use `git add -A` if you
confirmed in Step 0 there are no untracked files). In practice this is one or two files —
typically `projectName = "app4triqs"` in a freshly added `jenkins/Jenkinsfile`, plus the
`packaging/<app>-foss-*.eb.in` rename leaving diff3 markers.

## Step 5b — Verify nothing leaked (pure-Python apps especially)

Before committing, confirm the resolution didn't drag in C++/binding scaffolding the app
doesn't build:

```bash
# should print nothing for a pure-Python app:
git grep -nE '\$\{PROJECT_NAME\}_(c|warnings|python_modules)|add_cpp2py_module|c2py_add_module|add_subdirectory\(c\+\+' -- '*CMakeLists.txt'
git ls-files 'c++/**' 'doc/doxygen/**' '**/module.cpp' '**/*.wrap.*'
```

Auto-merged hunks (no conflict markers) leak C++ apparatus into **CI workflows** too — the
skeleton's `build.yml`/Jenkins steps build clair and pull a libclang toolchain to regenerate
bindings, which a pure-Python app never does. Check the CI files separately:

```bash
# should print nothing for a pure-Python app:
git grep -nE 'clair|clang_cxx|libclang|llvm-[0-9]+-dev|python3-clang|Update_Python_Bindings' \
  -- '.github/workflows/*' 'Jenkinsfile' 'jenkins/*'
```

For a pure-Python app, remove the clair build step + its `clang_cxx` matrix field, drop the
clair/c2py-only apt packages (`llvm-*-dev`, `libclang-*-dev`, `python3-clang*`), and keep only
the general compilers (`clang`, `g++`) the cmake `LANGUAGES CXX` configure still needs. (See
also Step 4b's `regenPlatforms = []` / drop-`sanitize` edits.)

Any hits on a pure-Python app mean a conflict was resolved the wrong way (or an auto-merged
hunk pulled C++ in) — go back and fix it. Then re-check no conflict markers remain (match only
the unambiguous markers — a bare `=======` false-matches RST heading underlines — but **include
the diff3 base marker `|||||||`**, which leaks past a `<<<<<<<`/`>>>>>>>`-only check whenever
`merge.conflictStyle=diff3` is set, as it is in some of these repos):
`git grep -nE '^(<<<<<<<|>>>>>>>|\|\|\|\|\|\|\|)' || echo clean`.

## Step 6 — Complete the merge commit

Finish the in-progress merge in a single two-parent commit that includes the normalization:

```bash
git commit --no-edit
```

(`--no-edit` keeps the message from Step 3.) The goal is a clean merge commit matching the
existing history — not a separate follow-up commit for the rename.

## Step 7 — Report

- `git log --oneline -3`
- `git diff --stat HEAD^1 HEAD` — what this merge actually changed.
- Re-list the incoming skeleton commits from Step 2.
- **For each tool/framework migration from Step 4c**: state whether it was adopted, rejected
  (pure-Python), or partially ported — and call out any customization that was **lost or
  needs the user/an external owner** (e.g. the `emailFailure()` recipient).

Then remind the user:
- **Build & test before pushing** — this skill does **not** configure, build, or run `ctest`.
- **Push is left to you** — the skill does not push.
