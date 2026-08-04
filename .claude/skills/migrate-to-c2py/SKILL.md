---
name: migrate-to-c2py
description: Migrate a TRIQS app's Python bindings from cpp2py (*_desc.py) to clair + c2py (.toml + .cpp + generated .wrap.*)
argument-hint: [<build-dir>]
effort: high
allowed-tools: Bash, Read, Edit, Glob, Grep
disable-model-invocation: true
---

Port the **current** TRIQS application from cpp2py-style bindings (hand-written `*_desc.py`
descriptors processed by `add_cpp2py_module` at build time) to clair + c2py (a `<module>.toml`
config + a thin `<module>.cpp` + clair-generated `*.wrap.cxx`/`*.wrap.hxx` committed to the tree).
Run from the repo root. This reproduces the ports already done for `app4triqs`, `ctseg`, `cthyb`,
`Nevanlinna`, and the TRIQS core Python modules.

This is **not** a pure-mechanical transform: each `_desc.py` is a hand-written spec of *what* to
wrap and *how* (renames, properties, dict-args, free functions, converters). The job is to
re-express that spec in c2py's two mechanisms — **C++ source annotations** + a **`.toml`** — and let
clair regenerate the wrap files. Read each `_desc.py` as the source of truth for the module's bound
surface, then make the generated bindings reproduce it.

Related skills: **`/regen-bindings`** owns Phase 7 (it runs the generator) — invoke it rather than
re-deriving the build flags. **`/merge-app4triqs`** owns the orthogonal doc-skeleton sync (conf.py,
doxygen, autosummary templates) that accompanied these ports — out of scope here. Commit with
**`/commit`**.

## Argument

`$ARGUMENTS` (optional): build directory, default `build`. Build dirs are usually symlinks onto
local disk — **never `rm -rf <build-dir>`**; clear contents with `rm -rf <build-dir>/*`.

## Context

- Repo: !`basename "$(git rev-parse --show-toplevel)"`
- `project(...)`: !`grep -E "^project\(" CMakeLists.txt | head -1`
- Has `c++/`: !`test -d c++ && echo yes || echo "no — pure-Python, nothing to migrate; stop"`
- cpp2py descriptors: !`git ls-files '*_desc.py'`
- Existing c2py toml (should be none pre-migration): !`git ls-files '*.toml' | grep python/ || echo none`
- Files mentioning cpp2py: !`git grep -il cpp2py -- ':!*.wrap.*' || echo none`
- `clair-c2py` on PATH: !`command -v clair-c2py || echo "(NOT found — see Phase 7)"`
- Current branch: !`git rev-parse --abbrev-ref HEAD`
- Working tree: !`git status --porcelain | head`

## Phase 0 — Preflight & read the spec

1. **Confirm this is a cpp2py app to migrate.** Need `c++/` **and** `*_desc.py` and **no**
   `python/**/*.toml`. If there are no `_desc.py` (and toml exist) it's already migrated — stop.
   If there's no `c++/` it's pure-Python — stop. (Detection matches `/regen-bindings` Phase 1.)
2. **Clean tree on a feature branch.** Tracked files must be clean (`git status --porcelain`); if
   not, stop and ask the user to commit/stash. Work on a dedicated branch.
3. **Inventory the modules.** One `<module>_desc.py` → one c2py module. For **each**, read the
   descriptor and extract its bound surface — this is the spec you must reproduce:
   - `module.add_class(...)` → `py_type` (Python name) vs `c_type` (C++ name) → **renames**.
   - `c.add_member(..., read_only=True)` / `c.add_property(...)` → **properties**.
   - `add_constructor("...", **dict)` / `CPP2PY_ARG_AS_DICT` → **param-struct-as-dict** ctors.
   - `module.add_function(...)` at module scope → **free functions** (may need `extern template`).
   - enums, `module.add_imports(...)`, and the `add_preamble` **converter includes**.
   - any `hdf5 = ...`, `serialize`/`h5_read_construct` → stay ignored in c2py.
   - **`doc=r"""…"""` strings** on classes/members/functions/enums and the module `doc=` /
     `--moduledoc`. In cpp2py these often live **only in the (hand-written) descriptor**, or are
     richer than the C++ comment. c2py sources docstrings **solely from the C++ `///` / `/** */`
     comments**, so these must be reconciled into the headers first — **Phase 3**. Flag whether the
     descriptor is auto-generated (`# Generated automatically … c++2py …` header, docs already in
     C++) or **hand-written/hand-edited** (docs diverge — tprf's `*_desc.py` are this case).

Restate, per module: name, wrapped classes (+ rename), properties, dict-ctor params, free
functions, enums, which converters it pulled in, and **whether the descriptor holds authoritative
docstrings not yet in the headers**. The rest of the phases turn this into code.

## Phase 1 — Build-system dependency swap

1. **Root `CMakeLists.txt`**: change the comment `# Load TRIQS and CPP2PY` → `# Load TRIQS`
   (cosmetic but expected; nothing else there references cpp2py).
2. **`deps/CMakeLists.txt`**: delete the `# -- Cpp2Py --` `external_dependency(Cpp2Py …)` block,
   replace with the canonical c2py block (place where Cpp2Py was, before GTest):
   ```cmake
   # -- c2py --
   if(PythonSupport OR (NOT IS_SUBPROJECT AND Build_Documentation))
     external_dependency(c2py
       GIT_REPO https://github.com/flatironinstitute/c2py
       GIT_TAG unstable
       BUILD_ALWAYS
       EXCLUDE_FROM_ALL
     )
   endif()
   ```
   (Early ports used a per-module `FetchContent(c2py)` in `python/.../CMakeLists.txt`; the **current
   canonical form** is `external_dependency` in `deps/` — match that.)
3. **Leftover references**: from the Context `git grep -il cpp2py` list, clean the remaining
   non-binding mentions — `share/CMakeLists.txt`, `share/cmake/<app>-config.cmake.in`,
   `share/<app>.modulefile.in`, `doc/CMakeLists.txt` (drop `CPP2PY_*` path vars / find lines).
   Leave `doc/ChangeLog.md` and historical comments alone.

## Phase 2 — Per-module c2py config (`.toml` + `.cpp`)

For each module, create two files next to the old descriptor.

**`<module>.toml`** — the filter spec (LLVM regex):
```toml
package_name = "triqs_<app>"
documentation = "<one-line module doc>"
namespaces = "triqs_<app>"
match_names = "triqs_<app>::(TypeA|TypeB|free_fn|SomeEnum)"
# wrap_no_arg_methods_as_properties = true   # only if the descriptor made no-arg getters properties wholesale
```
- `namespaces` (space-separated): **only** elements declared in exactly these namespaces are
  considered (so `::detail` is excluded automatically).
- `match_names`: restrict to the types/functions/enums this module wraps — the parenthesized
  alternation of the names you inventoried. Omit to wrap everything in the namespace; `reject_names`
  and `match_files` are also available.
- `wrap_no_arg_methods_as_properties = true` turns every no-arg method into a property (cthyb uses
  it); otherwise mark individual getters with `C2PY_PROPERTY_GET` (Phase 3).

**`<module>.cpp`** — the thin TU that clair reads and the wrap is injected into:
```cpp
#include <c2py/c2py.hpp>

// converter includes — translate the old _desc.py add_preamble (see mapping below)
#include <nda/c2py/converters.hpp>
#include <triqs/c2py_converters/gf.hpp>
#include <triqs/c2py_converters/mesh.hpp>
// ... only the ones this module actually needs

#include <triqs_<app>/<module-header>.hpp>

// cross-module type sharing: include the .wrap.hxx of any *other* module
// (this app or core triqs) whose wrapped types appear in this module's API
#include "./<other-module>.wrap.hxx"            // intra-app
#include <triqs/utility/utilities.wrap.hxx>      // cross-app (installed by triqs)

#include "<module>.wrap.cxx"   // generated in Phase 7 — last line
```

**cpp2py → c2py converter-include mapping** (rewrite the descriptor's `add_preamble`):
| cpp2py include | c2py include |
|---|---|
| `cpp2py/converters/{map,optional,pair,vector,string,std_array}.hpp` | *(built into `<c2py/c2py.hpp>` — drop)* |
| `nda_py/cpp2py_converters.hpp` | `<nda/c2py/converters.hpp>` |
| `triqs/cpp2py_converters/<X>.hpp` | `<triqs/c2py_converters/<X>.hpp>` |

**Free-function modules** (e.g. tprf's `lattice`/`linalg`, templated factories): in `<module>.cpp`,
above the wrap include, add a `c2py_module` alias block and `extern template` declarations for every
instantiation the descriptor exported (pattern from triqs `atom_diag.cpp`):
```cpp
namespace c2py_module {
  using AtomDiagReal = triqs::atom_diag::atom_diag<false>;
}
namespace triqs::atom_diag {
  extern template double partition_function(atom_diag<false> const &, double);
  // ... one per exported overload/specialization
}
```

## Phase 3 — C++ header docstrings & annotations

Edit the headers the descriptor wrapped. Two jobs in the same files, in this order:

1. **Migrate docstrings** (`3a`) — c2py reads docs *only* from C++ `///` / `/** */` comments, so
   every `doc=` string in `*_desc.py` is lost the moment the descriptor is deleted. Headers must
   be **clean doxygen** before generating; leftover RST is silently mangled, not rendered
   literally. Do this as its own commit before the port commit.
2. **Add annotations** (`3b`) — `CPP2PY_*` → `C2PY_*` renames, properties, class renames, and
   returning concrete values instead of references/`auto`.

Both jobs are lookup-heavy. Read
`${CLAUDE_SKILL_DIR}/references/docstrings-and-annotations.md` for the cpp2py/RST → doxygen
conversion table, the annotation catalog, and the verification greps before editing any header.

## Phase 4 — Prepare param-struct types (solver-style apps)

c2py's dict conversion needs param structs (`constr_params_t`, `solve_params_t`, …) to be
**aggregates**. If the descriptor used `CPP2PY_ARG_AS_DICT`, do a **separate prep commit** first
(cthyb did — "Prepare param types …"):
- Remove user-defined constructors from the param structs (`solve_parameters_t() {}`,
  `solve_parameters_t(h_int, n_cycles)` → gone).
- Add `bool operator==(T const &) const = default;` if any C++ test compares them.
- Update every C++ caller/test from positional `T(a, b)` to **designated initializers**
  `T{.h_int = a, .n_cycles = b}` (search `test/c++` and the app's own `c++`).
- Build + run the C++ tests to confirm this prep is correct *before* touching bindings.

## Phase 5 — `python/triqs_<app>/CMakeLists.txt`

Delete the cpp2py block (the `*_desc.py` glob, the `*_desc.py EXCLUDE` install pattern, and the
`foreach(gen …) add_cpp2py_module(…) endforeach()` loop). Replace with:
```cmake
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} DESTINATION ${TRIQS_PYTHON_LIB_DEST_ROOT} FILES_MATCHING PATTERN "*.py")

# Add Python modules
c2py_add_module(<module>  LINK_LIBRARIES ${PROJECT_NAME}_c ${PROJECT_NAME}_warnings)
# multiple modules: order them and declare cross-module binding deps
c2py_add_module(<other>   LINK_LIBRARIES ${PROJECT_NAME}_c ${PROJECT_NAME}_warnings DEPENDS_ON_BINDINGS <module>)
install(TARGETS <module> <other> DESTINATION ${PYTHON_LIB_DEST})
```
- `c2py_add_module(<name> [DIR <subdir>] [LINK_LIBRARIES …] [DEPENDS_ON_BINDINGS …])` builds
  `<DIR>/<name>.cpp`, links `c2py::c2py` automatically, and (under `-DUpdate_Python_Bindings=ON`)
  wires clair generation. **`DEPENDS_ON_BINDINGS`** forces a module's `.wrap.hxx` to be generated
  before a module that `#include`s it (Phase 2) — required for intra-app cross-module sharing.
- Modules in a subdir (tprf's `lattice/`, `linalg/`) take `DIR <subdir>`.

## Phase 6 — Python package wiring (`__init__.py`, high-level `.py`, docs)

- **Export the new wrapped names**: `from .solver_core import SolverCore, ConstrParamsT, …`; update
  `__all__`. Names are the c2py `tp_name` (CamelCase of the C++ type, e.g. `solve_params_t` →
  `SolveParamsT`).
- **Delete the `Cpp2pyInfo` class** if present in `__init__.py`.
- **Register converters via import** — the subtle runtime gotcha: a wrapped type's converter is
  registered only when its module is imported. If the app returns a foreign wrapped type (e.g.
  cthyb returns `dict[..., triqs::stat::histogram]`), import the provider in `__init__.py`:
  `from triqs.stat.histograms import Histogram` — else callers hit
  `RuntimeError: The type … can not be converted`. (cpp2py's `add_imports` did this implicitly.)
- **Fix high-level wrappers** (`solver.py`, etc.) for anything that changed: property-vs-method
  access, renamed param types, by-value returns.
- **Delete** the old `*_desc.py` and any generated `parameters_*.rst` / `constr_*.rst` doc stubs the
  descriptor produced.

## Phase 7 — Generate the wrap files

Delegate to **`/regen-bindings`** (it configures `-DUpdate_Python_Bindings=ON`, builds the module
targets so the `*.wrap.cxx`/`*.wrap.hxx` are written next to each `<module>.cpp`, and reviews the
diff). If `clair-c2py` is not on PATH (see Context), it lives in `~/opt/clair` — add its `bin/` to
PATH (or build/install clair) first. **Never hand-edit `*.wrap.*`** — fix the C++/toml and regenerate.

## Phase 8 — Build, test, iterate

`ctest --test-dir <build-dir> -j 16`. Common failures and where they come from:
- `RuntimeError: The type … can not be converted` → missing converter `#include` in `<module>.cpp`
  (Phase 2) **or** missing import in `__init__.py` (Phase 6).
- A wrapped method/property missing in Python → it wasn't matched by `match_names`, or the getter
  lacks `C2PY_PROPERTY_GET` / returns a reference (Phase 3).
- Wrong Python name → add/adjust `C2PY_RENAME`.
- Param dict ctor rejected → the struct still has a user-defined constructor (Phase 4).
Loop: edit C++/toml → regenerate (Phase 7) → rebuild → retest.

## Phase 9 — Commit

Mirror the observed history — separate, well-scoped commits:
1. *(hand-written descriptors)* `Migrate Python docstrings into headers / doxygen style` (Phase 3a)
   — header comment reflow only, before any binding change.
2. *(if applicable)* `Prepare param types for port to clair + c2py` (Phase 4, with the test edits).
3. `Port to clair + c2py` — deps, CMakeLists, `.toml`/`.cpp`, header annotations, `__init__.py`,
   high-level `.py`, deletion of `_desc.py`/rst.
4. `Generate python bindings for the <…> module` — the regenerated `*.wrap.cxx`/`*.wrap.hxx` only.

Use **`/commit`** (runs clang-format). Do not push. The doc-skeleton sync (conf.py.in, doxygen,
autosummary) that accompanied the reference ports is **separate** — pull it via `/merge-app4triqs`
if wanted.

## Report

- Per module: classes/free-fns/enums wrapped, renames, properties, converters pulled in.
- Files added (`.toml`/`.cpp`/`.wrap.*`), deleted (`_desc.py`/rst), and CMake/deps edits.
- Descriptor type (auto-generated vs hand-written) and what docstrings were migrated to headers /
  converted to doxygen (Phase 3a), or N/A.
- Param-type prep done or N/A; any `__init__.py` converter imports added.
- Test result (`ctest` pass/fail with output); anything left for the user.
- Reminder: **uncommitted/local** — nothing pushed.
