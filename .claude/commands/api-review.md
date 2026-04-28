---
description: Extract and summarize public API changes between the current branch and a base branch
effort: medium
allowed-tools: Bash, Read, Glob, Grep, Write
---

Produce a structured public-API review of the current branch vs. a base branch.

## Setup

- Current branch: !`git branch --show-current`
- Base branch: **${ARGUMENTS}** — if empty, default to `unstable`, then `main`, then `master`. Verify with `git rev-parse --verify <base>`; if none found, report and stop. Bind the result to `BASE`.
- Output file: `/tmp/api-review-<current>-vs-<base>.md` via the Write tool. After writing, print a short summary (counts of new/modified files, flag count, coverage summary) and the file path. Use fenced ```cpp / ```python blocks for snippets.

## Step 1: Detect binding system + categorize changed files

Detect which Python-binding system the repo uses by inspecting the working tree:
- **clair+c2py** (modern, used in `triqs`): per-module `python/**/*.toml`, `*.wrap.cxx` / `*.wrap.hxx` files, `C2PY_*` annotations in headers
- **legacy cpp2py** (still used in `h5` and other unmigrated repos): `python/**/*_desc.py` files with `add_constructor` / `add_method` / `add_property` calls

Both can coexist briefly during migration. Note which system applies and use the matching extraction rules below.

```
git diff --name-status --diff-filter=ACMRD "${BASE}...HEAD"
```

**Public-API files** (analyze):
- `c++/**/*.hpp` — exclude `test/`, `third_party/`, `**/detail/**`. Also drives the Python binding under clair+c2py via `C2PY_*` annotations.
- **clair+c2py only** — `python/**/*.toml` (clair config), `python/**/*.cpp` (per-module binding source).
- **legacy cpp2py only** — `python/**/*_desc.py` (Python binding descriptors).
- `python/**/*.py` — exclude tests and `__init__.py` unless it defines public API beyond imports / re-exports / `__all__`.

**Generated / non-API files** (count only): `*.wrap.cxx`, `*.wrap.hxx` (clair output), `.cpp` implementation files, `CMakeLists.txt`, `*.cmake`, `test/**`, `doc/**`, build/CI.

If no public-API files changed, report "No public API changes detected", list non-API files, stop.

## Step 2: Extract API per file

- **A (added)**: read whole file, extract everything below.
- **M (modified)**: `git diff "${BASE}...HEAD" -- <file>`, read current file for context, extract only added/modified API.
- **D (deleted)**: list removed API from `git show ${BASE}:<file>`.

### C++ headers (.hpp) — extract from `public:` and namespace scope

- Class/struct: name, template params, base classes, Doxygen brief; under clair+c2py also any `C2PY_RENAME(PyName)` (note both C++ and Python names).
- Public constructors with parameters and defaults. Under clair+c2py all non-ignored constructors are auto-bound.
- Public member functions: full signature including `[[nodiscard]]`, `const`, `noexcept`, return type, defaults; include `///` or `@brief` doc (clair forwards these as Python docstrings).
- Under clair+c2py — `C2PY_PROPERTY_GET(py_name)` getters become Python properties (note the `py_name` and the C++ method name); `C2PY_IGNORE` items: list as "(hidden from Python)" without full extraction.
- Public type aliases (`using`).
- Operators.
- Options/config structs: every member with type, default, per-member doc.
- Free functions at namespace scope (full signature + brief). Under clair+c2py exposure to Python depends on `extern template` lines in the corresponding `python/.../*.cpp`.
- Friend serializers/MPI (`h5_write`, `h5_read`, `mpi_broadcast`, `mpi_reduce`) — group as "Serialization/MPI" and just list which exist.
- Concepts and enums.

Skip: `private:`/`protected:` sections, `#ifdef C2PY_INCLUDED` blocks, include guards, copyright, `#include`s, inline function bodies (signature only). Group overloads of the same function.

### clair+c2py — `python/**/*.toml`

Record `package_name`, `documentation`, and the `namespaces` list. Changes to `namespaces` mean new/removed C++ namespaces exposed to Python.

### clair+c2py — `python/**/*.cpp` (per-module source)

- `namespace c2py_module` type aliases (e.g. `using AtomDiagReal = triqs::atom_diag::atom_diag<false>;`) — these define which template instantiations land in Python and under what name.
- `extern template` declarations for free functions — additions/removals here are the canonical signal that a free function was added/removed from the Python surface.

### Legacy cpp2py — `python/**/*_desc.py`

- Python class name (`py_type`) and its C++ type (`c_type`).
- Each `add_constructor()` with its C++ signature and doc string.
- Each `add_method()` / `add_method_copy()` with name, signature, and doc.
- Each `add_property()` with name, getter/setter signature, and doc.
- Module-level functions via `module.add_function()`.

### Python modules (`__init__.py`, `*.py`)

`__init__.py` typically re-exports symbols from the compiled `.so` and adds hand-written wrappers. Extract:
- `from .<module> import ...` lines (the public surface).
- Hand-written class defs + docstrings; `__init__` signature and param docs.
- Public method signatures (skip `_`-prefixed except dunders); `@property` + docs.
- Module-level functions (factories, helpers) with signatures and docstrings.
- `__all__` if present.

## Step 3: Test coverage

Find tests by (a) collecting new/modified files under `test/` from the diff, and (b) grepping `test/c++/` and `test/python/` for usages of each new class/function/Python name (remember `C2PY_RENAME` — search for both names). Map tests → API elements.

Classify each public class / free function / method / property:
- **Tested** — directly called/exercised
- **Indirectly tested** — exercised through a higher-level test
- **Untested** — no test references it

Check: constructors + key methods for classes; each overload for free functions; round-trip for `h5_write`/`h5_read`; MPI broadcast under MPI; non-default values for options structs; invalid-input error paths; both C++ and Python entry points where applicable.

## Step 4: Flags

Scan for `TODO`/`FIXME`/`HACK`/`XXX` (quote verbatim), missing `///`/`@brief`/docstrings on public symbols (these become the Python docstrings), `[[deprecated]]`/`@deprecated`, inconsistent naming/parameter ordering across overloads. Under clair+c2py also flag: bound C++ methods (no `C2PY_IGNORE`) with no documentation; free functions added in a header without a matching `extern template` in the binding `.cpp` (effectively unbound); `C2PY_RENAME` whose Python name diverges from project conventions. Under legacy cpp2py also flag: public C++ methods with no corresponding `add_method` when peers on the same class are bound.

## Output format

```
# Public API Review: <current> vs <base>

## Summary
- N new / N modified / N deleted public API files
- N non-API files changed (not shown)

---

## New Files

### `<filepath>`
<file-level Doxygen / module docstring>
**Namespace**: `triqs::xyz`

#### `class ClassName` — <brief>     [Python: `PyName` via C2PY_RENAME]
- **Template params**: `<typename T, int N>`
- **Base class**: `base_class<T>`
- **Constructors**:
  - `ClassName(type1 param1, type2 param2 = default)`
- **Methods**:
  - `[[nodiscard]] return_type method_name(params) const` — <brief>
- **Properties (C2PY_PROPERTY_GET)**:
  - `py_name` ← `cpp_method_name() const` — <brief>
- **Hidden from Python (C2PY_IGNORE)**:
  - `internal_method(...)`
- **Type aliases**: `using alias = type;`
- **Serialization/MPI**: h5_write, h5_read, mpi_broadcast

#### `struct options_t` — <brief>
| Member | Type | Default | Description |
|--------|------|---------|-------------|

#### Free Functions
- `template <typename T> return_type func(params)` — <brief>
  - Python: bound via `extern template` in `python/.../mod.cpp` (instantiations: `<T=double>`, `<T=dcomplex>`)

#### Python binding (`python/.../mod.toml`, `mod.cpp`, `__init__.py`)
- `package_name`, `namespaces`
- Template instantiations exposed: `AtomDiagReal`, `AtomDiagComplex`
- `__init__.py` re-exports / factories / `__all__`

---

## Modified Files

### `<filepath>` — <one-line summary>
#### Added / Changed (`old → new`) / Removed

---

## Test Coverage

### `<filepath>` (tested by: `test/...`, ...)
| API Element | Coverage | Test File(s) | Notes |

### Coverage Summary
- N / M tested, N / M untested
- Key gaps: ...

---

## Flags
- [ ] `<file>:<line>` — TODO: <text>
- [ ] `<file>` — Missing docstring on `function_name()` (becomes empty Python docstring)
- [ ] `<file>` — `free_func` added but no `extern template` in `python/.../mod.cpp` → unbound in Python
- [ ] `<file>` — `C2PY_RENAME(Foo)` inconsistent with sibling classes
```

## Guidelines

- For files >500 lines, focus on changed regions, not full extraction.
- Include the full `template <...>` line where applicable.
- Preserve parameter names and defaults verbatim.
- Include full `@param` blocks when present.
- Group related free functions with their class.
- For each Python-visible C++ entity, note its Python name explicitly when it differs (`C2PY_RENAME`, `C2PY_PROPERTY_GET`).
