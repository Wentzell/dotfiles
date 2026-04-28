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

## Step 1: Categorize changed files

```
git diff --name-status --diff-filter=ACMRD "${BASE}...HEAD"
```

**Public-API files** (analyze):
- `c++/**/*.hpp` — exclude `test/`, `third_party/`, `**/detail/**`. Also drives the Python binding via `C2PY_*` annotations (clair+c2py framework).
- `python/**/*.toml` — clair binding config (declares `package_name`, `namespaces`).
- `python/**/*.cpp` — small per-module binding source: `namespace c2py_module` type aliases (template instantiations), `extern template` declarations for exposed free functions, and the `#include "*.wrap.cxx"` line.
- `python/**/*.py` — exclude tests; usually `__init__.py` re-exports the compiled `.so` and adds hand-written wrappers / factories / `__all__`.

**Generated / non-API files** (count only): `*.wrap.cxx`, `*.wrap.hxx` (clair output), `.cpp` implementation files, `CMakeLists.txt`, `*.cmake`, `test/**`, `doc/**`, build/CI.

If no public-API files changed, report "No public API changes detected", list non-API files, stop.

## Step 2: Extract API per file

- **A (added)**: read whole file, extract everything below.
- **M (modified)**: `git diff "${BASE}...HEAD" -- <file>`, read current file for context, extract only added/modified API.
- **D (deleted)**: list removed API from `git show ${BASE}:<file>`.

### C++ headers (.hpp) — extract from `public:` and namespace scope

- Class/struct: name, template params, base classes, Doxygen brief, and any `C2PY_RENAME(PyName)` (note both C++ and Python names).
- Public constructors with parameters and defaults — all non-ignored constructors are auto-bound.
- Public member functions: full signature including `[[nodiscard]]`, `const`, `noexcept`, return type, defaults; include `///` or `@brief` doc (clair forwards these as Python docstrings).
- `C2PY_PROPERTY_GET(py_name)` getters — list as Python properties under `py_name`, noting the C++ method name.
- `C2PY_IGNORE` items — note as "(hidden from Python)" without full extraction.
- Public type aliases (`using`).
- Operators.
- Options/config structs: every member with type, default, per-member doc.
- Free functions at namespace scope (full signature + brief). Whether they are exposed to Python depends on `extern template` lines in the corresponding `python/.../*.cpp` (Step 2, Python module source).
- Friend serializers/MPI (`h5_write`, `h5_read`, `mpi_broadcast`, `mpi_reduce`) — group as "Serialization/MPI" and just list which exist.
- Concepts and enums.

Skip: `private:`/`protected:` sections, `#ifdef C2PY_INCLUDED` blocks, include guards, copyright, `#include`s, inline function bodies (signature only). Group overloads of the same function.

### Python binding config (`*.toml`)

Record `package_name`, `documentation`, and the `namespaces` list. Changes to `namespaces` mean new/removed C++ namespaces exposed to Python.

### Python module source (`python/.../*.cpp`)

- `namespace c2py_module` type aliases (e.g. `using AtomDiagReal = triqs::atom_diag::atom_diag<false>;`) — these define which template instantiations land in Python and under what name.
- `extern template` declarations for free functions — additions/removals here are the canonical signal that a free function was added/removed from the Python surface.

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

Scan for `TODO`/`FIXME`/`HACK`/`XXX` (quote verbatim), missing `///`/`@brief`/docstrings on public symbols (these become the Python docstrings), `[[deprecated]]`/`@deprecated`, public C++ methods that are bound (no `C2PY_IGNORE`) but lack documentation, free functions added in a header without a matching `extern template` in the binding `.cpp` (effectively unbound), inconsistent naming/parameter ordering across overloads, and `C2PY_RENAME` whose Python name diverges from the project's naming conventions.

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
