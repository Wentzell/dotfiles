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
- `c++/**/*.hpp` — exclude `test/`, `third_party/`, `**/detail/**`
- `python/**/*_desc.py`
- `python/**/*.py` — exclude `__init__.py` (unless it defines public API beyond imports) and tests

**Non-API files** (count only): `.cpp`, `CMakeLists.txt`, `*.cmake`, `test/**`, `doc/**`, build/CI.

If no public-API files changed, report "No public API changes detected", list non-API files, stop.

## Step 2: Extract API per file

- **A (added)**: read whole file, extract everything below.
- **M (modified)**: `git diff "${BASE}...HEAD" -- <file>`, read current file for context, extract only added/modified API.
- **D (deleted)**: list removed API from `git show ${BASE}:<file>`.

### C++ headers (.hpp) — extract from `public:` and namespace scope

- Class/struct: name, template params, base classes, Doxygen brief
- Public constructors with parameters and defaults
- Public member functions: full signature including `[[nodiscard]]`, `const`, `noexcept`, return type, defaults; include `@brief` if present
- Public type aliases (`using`)
- Operators
- Options/config structs: every member with type, default, per-member doc
- Free functions at namespace scope (full signature + brief)
- Friend serializers/MPI (`h5_write`, `h5_read`, `mpi_broadcast`, `mpi_reduce`) — group as "Serialization/MPI" and just list which exist
- Concepts and enums

Skip: `private:`/`protected:` sections, `#ifdef C2PY_INCLUDED` blocks, include guards, copyright, `#include`s, inline function bodies (signature only). For `C2PY_IGNORE`: note "(hidden from Python)" without full extraction. Group overloads of the same function.

### Python descriptors (`*_desc.py`)

`py_type` + `c_type`; each `add_constructor` / `add_method` / `add_method_copy` / `add_property` (signature + doc); module-level `module.add_function`.

### Python modules (`.py`)

Class defs + docstrings; `__init__` signature and param docs; public method signatures (skip `_`-prefixed except dunders); `@property` + docs; module-level functions + docs; `__all__` if present.

## Step 3: Test coverage

Find tests by (a) collecting new/modified files under `test/` from the diff, and (b) grepping `test/c++/` and `test/python/` for usages of each new class/function name. Map tests → API elements.

Classify each public class / free function / method:
- **Tested** — directly called/exercised
- **Indirectly tested** — exercised through a higher-level test
- **Untested** — no test references it

Check: constructors + key methods for classes; each overload for free functions; round-trip for `h5_write`/`h5_read`; MPI broadcast under MPI; non-default values for options structs; invalid-input error paths.

## Step 4: Flags

Scan for `TODO`/`FIXME`/`HACK`/`XXX` (quote verbatim), missing `@brief`/docstrings on public symbols, `[[deprecated]]`/`@deprecated`, public C++ methods unbound when peer methods on the same class are bound, inconsistent naming/parameter ordering across overloads.

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

#### `class ClassName` — <brief>
- **Template params**: `<typename T, int N>`
- **Base class**: `base_class<T>`
- **Constructors**:
  - `ClassName(type1 param1, type2 param2 = default)`
- **Methods**:
  - `[[nodiscard]] return_type method_name(params) const` — <brief>
- **Type aliases**: `using alias = type;`
- **Serialization/MPI**: h5_write, h5_read, mpi_broadcast

#### `struct options_t` — <brief>
| Member | Type | Default | Description |
|--------|------|---------|-------------|

#### Free Functions
- `template <typename T> return_type func(params)` — <brief>

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
- [ ] `<file>` — Missing docstring on `function_name()`
- [ ] `<file>` — `method_x` is public C++ but unbound in Python
```

## Guidelines

- For files >500 lines, focus on changed regions, not full extraction.
- Include the full `template <...>` line where applicable.
- Preserve parameter names and defaults verbatim.
- Include full `@param` blocks when present.
- Group related free functions with their class.
