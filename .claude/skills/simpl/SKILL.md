---
name: simpl
description: Iteratively simplify code while keeping functionality
argument-hint: <file|directory|commit|range>
effort: high
disable-model-invocation: true
---

Iteratively simplify ${ARGUMENTS} without changing behavior. Requires a clean working tree
(`git status --porcelain`) — ask the user to commit or stash first.

## Scope

- A file or directory target means its contents; a commit target ("the last commit", a hash, `HEAD`) means
  the change it introduced (`git show <ref>`), and a series means the range diff (`git diff <base>...HEAD`,
  e.g. `@{upstream}...HEAD` or `main...HEAD`) — that diff is the scope, not the files it touched.
- Read the whole target before editing; when it spans more than ~10 files, ask the user to narrow it.
- Everything else — pre-existing code, lines the commit left alone — is outside the target: simplify it
  only by proposing a follow-up in the report, never by editing.

## Clarity is the goal, the diff is the constraint

Aim for code that reads better, but remember that a reviewer sees only the `git diff`: a clarity win they
cannot check is not delivered. Judge each candidate on clarity gained per line of diff.

- **Look first for clarity by deletion** — collapsing duplication the target itself introduced (an if/else
  it added, a copy-pasted block) improves the code and shrinks the diff at once.
- **Spend lines when they buy clarity.** Diff size decides between comparable options; it never vetoes a
  real improvement.
- **Never trade a small diff for a large one.** Rewriting untouched lines to accommodate a refactor is the
  wrong trade, and extracting a helper that swallows untouched code is the usual trap; the same clarity is
  usually reachable within the target's own lines.
- **Smaller is not automatically simpler.** A terser expression a reviewer cannot verify by eye (clever
  index arithmetic, parity tricks, chained ternaries) is worse than the lines it replaced.
- **Reshaping that reindents a block** (early return, unwrapping an `if`) shows the whole block as changed
  — worth it for a short block; for a long one, leave it or note that `git diff -w` reads it as the small
  change it is.
- When unsure how far the user wants to go, apply the minimal version and offer the larger one.

## What to look for

Roughly in priority order:

1. **Dead code** — unused parameters/variables/functions, unreachable paths, redundant null checks, commented-out blocks, unused includes/typedefs/forward decls.
2. **Clarity** — better names, early returns to flatten nesting, named constants for magic numbers, simplified booleans (`if (x == true)` → `if (x)`), structuring blank lines.
3. **Complexity** — split long functions, untangle clever code, flatten indirection, simplify long conditional chains, reduce parameter counts.
4. **Duplication** — unify divergent branches, extract helpers from repeated patterns, replace new code that re-implements an existing helper (grep neighboring and utility headers, and name the call to use instead).
5. **Modernization (C++20/23)** — concepts instead of `std::enable_if_t`, range-based algorithms, structured bindings, `auto` for obvious types, `std::ssize`, `std::optional` over nullable pointers.

Compiler warnings are simplification opportunities — grep the build output for `warning:`.

## Don't

- Change public API signatures or behavior, edge cases included — an edge case that looks like a latent bug gets flagged in the report, not fixed
- Add features, abstractions, or infrastructure
- Strip comments that explain non-obvious logic
- Make stylistic-only changes with no clarity benefit

## Workflow

For each iteration:

1. **Identify** one focused simplification: file/line, current snippet, proposed change, category, what it buys, lines added/removed. Stop if none remain.
2. **Apply** it with Edit; when it spans >3 files or shows in a public header, get the user's approval before editing.
3. **Verify** — `cmake --build <build> && ctest --test-dir <build> -j 16`, in the variant the user works in (`build_dbg`, …). Passing tests are not equivalence: if the change could alter arithmetic (reordered operations, a reused value, a restructured loop, a touched index or tolerance), also diff old-vs-new output bit-for-bit from a driver over a parameter sweep — renames, dead code and comments don't need it. On failure, revert the iteration (`git checkout -- <files>`) and skip it. Without tests, keep to provably equivalent changes and say so.
4. **Commit** one simplification per commit, e.g. "Use early return to reduce nesting in process()". A commit target still at `HEAD` and unpushed gets amended, its message updated where it no longer fits (say so if HEAD is detached). If it is pushed, amending forces a push over a live review — ask first. If it is not `HEAD`, commit `fixup! <subject>` for the user to autosquash instead of rewriting history (interactive rebase is unavailable).
5. **Report** the iteration, what changed and what it bought, files touched, `git diff --numstat` against the baseline before and after, test status, and what is left — out-of-target follow-ups, plus candidates you dropped (one line each, no arguing the case). Repeat up to 5 iterations or until exhausted.
