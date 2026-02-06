---
description: Run clang-format and commit pending changes
---

## Context

- Current branch: !`git branch --show-current`
- Git status: !`git status`
- Staged and unstaged changes: !`git diff HEAD`
- Recent commits: !`git log --oneline -10`

## Task

Commit pending changes:

1. Run `git clang-format` on all staged C++ source files to ensure consistent formatting. If clang-format made changes, stage those formatting changes as well.
2. If tests have not already been verified in this session, run them using `ctest` to ensure they pass. If tests fail, fix the issues before proceeding.
3. Create a commit with a concise message:
   - Start with a verb (Add, Fix, Update, Move, Make, etc.)
   - Match the style of recent commits
   - For multi-line descriptions, use bullet points with `-`
