---
description: Regenerate a TRIQS project's Python bindings in-tree and review the diff (c2py via -DUpdate_Python_Bindings=ON; cpp2py auto-regens at build)
argument-hint: [<build-dir>]
effort: medium
allowed-tools: Bash, Read, Glob, Grep
---

Regenerate the Python bindings of the **current** repo (a TRIQS app or core-lib) and present
the resulting `git diff` for review. Use this whenever the C++ public API changed (a release,
a TRIQS bump, a refactor that touched bound types). Run it from the repo root.

The mechanics differ by binding style, so the first job is to **detect the style** and do the
right thing — for two of the four cases there is nothing to regenerate.

## Argument

`$ARGUMENTS` (optional): build directory. Defaults to `build`. Build dirs are usually symlinks
onto local disk — **never `rm -rf <build-dir>`**; clear contents with `rm -rf <build-dir>/*` if
a reconfigure is needed.

## Context

- Repo: !`basename "$(git rev-parse --show-toplevel)"`
- `project(...)`: !`grep -E "^project\(" CMakeLists.txt | head -1`
- Has `c++/`: !`test -d c++ && echo yes || echo "no (pure-Python)"`
- c2py modules (`.toml`): !`git ls-files '*.toml' | grep -E 'python/' | head`
- cpp2py descriptors (`_desc.py`): !`git ls-files '*_desc.py' | head`
- Existing wrap files: !`git ls-files '*.wrap.cxx' '*.wrap.hxx' | head`
- `clair-c2py` available: !`command -v clair-c2py || echo "(NOT on PATH)"`
- Working tree: !`git status --porcelain | head`
- Build dir (default `build`) resolves: !`bd=build; if [ -d "$bd" ]; then echo "ok ($bd)"; elif [ -L "$bd" ]; then echo "DANGLING SYMLINK ($bd → $(readlink "$bd")) — recreate the target dir before configuring"; else echo "absent (fresh configure)"; fi`

## Phase 1 — Detect the binding style

Classify from the Context probes (the same matrix `/release-app` and `/merge-app4triqs` use):

| Evidence | Style | Action |
|---|---|---|
| `c++/` + `python/**/*.toml` (+ `*.wrap.*`) | **c2py** | Phases 2–4 below |
| `c++/` + `python/**/*_desc.py` | **cpp2py** | regenerated automatically on every build — **nothing to commit**; just rebuild (Phase 2a) and stop |
| `c++/` but neither toml nor `_desc.py` | **header-only / no bindings** | nothing to do — report and stop (e.g. `itertools`) |
| no `c++/` | **pure-Python** | no bindings — report and stop (e.g. `maxent`, `dft_tools`) |

State the detected style before proceeding.

### Phase 2a — cpp2py shortcut
cpp2py descriptors (`*_desc.py`) are processed by `add_cpp2py_module` at **build** time, so a
normal `cmake --build <build-dir>` already regenerates the bound module — there are no
generated source files tracked in git, hence nothing to review or commit. Build to confirm it
still generates cleanly, report "cpp2py: regenerated at build, no tracked artifacts", and stop.

## Phase 2 — (c2py) confirm the generator is available

c2py regeneration shells out to `clair-c2py`. The CMake wiring
(`c2py/share/cmake/clair_c2py_generate_bindings.cmake`) uses an in-tree `clair-c2py` target if
the build contains one, otherwise `find_program(clair-c2py REQUIRED)` — which **hard-fails the
configure** if it's not found. From Context: if `clair-c2py` is not on `PATH` and there is no
in-tree clair build, **stop** and tell the user to build/install clair (it lives in
`~/opt/clair`; add its `bin/` to `PATH`).

## Phase 3 — (c2py) regenerate

Binding generation is wired as a dependency of each c2py **module target**, so building the
module regenerates the `*.wrap.cxx` / `*.wrap.hxx` files **in the source tree**. The generator
reads `compile_commands.json` and the C++20 **modmap** of the module object — which only exists
once the module's `.cpp` has been compiled — so you must build the **module/whole project**, not
the isolated `<module>_bindings_generation` target (that errors with `… .cpp.o.modmap: no such
file`).

**Prefer flipping the flag on the repo's existing build dir** — it already carries the
repo-specific configure flags (some repos, e.g. `h5`, FATAL_ERROR without `-DCMAKE_INSTALL_PREFIX`;
apps need a matching TRIQS install on `CMAKE_PREFIX_PATH`/`PYTHONPATH`). If that dir is a **dangling
symlink** (its local-disk target was deleted — see Context), recreate the target first
(`mkdir -p "$(readlink <build-dir>)"`); configuring into a dangling symlink fails with a confusing
`Unable to (re)create the private pkgRedirects directory` error, not an obvious "missing directory".
Reconfiguring just adds the two flags:

```bash
cmake <build-dir> -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DUpdate_Python_Bindings=ON   # reuse existing config
cmake --build <build-dir>                                                          # builds module → regenerates wrap files
```

Only if there is no usable build dir, configure a fresh one — but then add **all** flags the repo
normally needs (`-S . -B <build-dir> -GNinja` plus its `-DCMAKE_INSTALL_PREFIX=…` / TRIQS prefix),
not just the two above. If configure fails on a TRIQS version check or a missing install prefix,
that's a precondition problem, not a binding problem — report it and stop.

The wrap files are written next to each `<module>.cpp` (the custom command's working directory is
the module source dir). `*.wrap.hxx` is (re)generated only for modules that export wrapped types.
The bound output to review/commit is **only** the `*.wrap.*` files — ignore any transient index
artifacts the clang-based tooling may drop in the working dir.

## Phase 4 — (c2py) review the diff

```bash
git diff --stat -- '*.wrap.cxx' '*.wrap.hxx'
git diff -- '*.wrap.cxx' '*.wrap.hxx'
```

- A **non-empty** diff after an API change is expected — eyeball it for sanity (new/renamed
  methods appear, `C2PY_RENAME`/property mappings are honored), but do **not** hand-edit
  `*.wrap.*` — they are generated; fix the C++ source or its annotations and regenerate instead.
- An **empty** diff means the bound surface didn't change — fine, nothing to commit.
- These flags only affect this build dir; for normal development reconfigure with
  `-DUpdate_Python_Bindings=OFF` (or use a separate build dir) so ordinary builds don't depend
  on `clair-c2py`.

## Report

- Detected style (c2py / cpp2py / header-only / pure-Python) and why.
- For c2py: which `*.wrap.*` files changed (or "no change"); a one-line summary of the API delta
  the diff reflects.
- Reminder: **changes are uncommitted** — commit the regenerated bindings together with the C++
  change that motivated them (a `/commit` follow-up); this skill does not commit or push.
