---
description: Iteratively simplify code while keeping functionality
argument-hint: <file|directory>
effort: high
---

Iteratively simplify ${ARGUMENTS} without changing behavior.

## Prerequisites

- Working directory must be clean (`git status --porcelain`); ask user to commit/stash if not.
- For a directory: read all relevant files. For a large directory (>10 files), ask user to narrow scope.

## What to look for

Roughly in priority order:

1. **Dead code** — unused parameters/variables/functions, unreachable paths, redundant null checks, commented-out blocks, unused includes/typedefs/forward decls.
2. **Clarity** — better names, early returns to flatten nesting, named constants for magic numbers, simplified booleans (`if (x == true)` → `if (x)`), structuring blank lines.
3. **Complexity** — split long functions, untangle clever code, flatten indirection, simplify long conditional chains, reduce parameter counts.
4. **Duplication** — extract helpers from repeated patterns, unify divergent implementations.
5. **Modernization (C++20/23)** — concepts instead of `std::enable_if_t`, range-based algorithms, structured bindings, `auto` for obvious types, `std::ssize`, `std::optional` over nullable pointers.

Compiler warnings are simplification opportunities — `cmake --build build 2>&1 | grep -E "warning:|error:"`.

## Don't

- Change public API signatures or behavior (even edge cases)
- Add features, abstractions, or infrastructure
- Strip comments that explain non-obvious logic
- Make stylistic-only changes with no clarity benefit

## Workflow

For each iteration:

1. **Identify** a focused simplification with file/line, current snippet, proposed change, category, and rationale. Stop if none remain.
2. **Apply** the change with Edit. If the change spans >3 files or touches public APIs, present to user first.
3. **Verify** — `cmake --build build && ctest --test-dir build -j 16`. If tests fail, revert (`git checkout -- <file>`) and skip. If tests are unavailable, restrict to provably equivalent changes, one per iteration, and document the limitation.
4. **Commit** focused, e.g. "Use early return to reduce nesting in process()", "Extract common validation into validate_input()". Each commit covers one simplification (or a tightly related group).
5. **Iterate** — report iteration number, what was simplified, files changed, test status, remaining opportunities. Repeat up to 5 iterations or until exhausted.
