---
description: Run clang-format and commit pending changes
effort: medium
allowed-tools: Bash, Read, Glob, Grep
---

## Context

- Branch: !`git branch --show-current`
- Status: !`git status`
- Diff: !`git diff HEAD`
- Recent commits: !`git log --oneline -10`

## Task

1. Run `git clang-format` on staged C++ files; stage any resulting changes.
2. If tests have not already passed in this session, run `ctest` and fix any failures first.
3. Commit with a concise message:
   - Start with a verb (Add, Fix, Update, Move, Make, ...)
   - Match the style of recent commits
   - Bullet multi-line descriptions with `-`
