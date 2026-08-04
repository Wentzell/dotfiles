# Tool/framework migrations

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
