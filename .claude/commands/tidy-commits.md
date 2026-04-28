---
description: Reorganize and clean up git commit history
argument-hint: <commit-range>
effort: medium
allowed-tools: Bash, Read, Glob, Grep
---

Tidy commits in ${ARGUMENTS}. Confirm the reorganization plan with the user before making any changes.

## Prerequisites

- Working directory must be clean (`git status --porcelain`); ask user to commit/stash if not.

## Analyze

The range includes both endpoints. Adjust accordingly:
- `A..B` → use `A^..B`
- `HEAD~N..HEAD` → use `HEAD~$((N+1))..HEAD`

For each commit, get message, files, and diff:
```bash
git log --reverse --format="%H%n%s%n%b%n---" <adjusted-range>
git show --stat --format="" <sha>
git show -p <sha>
```

Identify fix commits by message pattern (`fix`, `fixup`, `WIP`, `typo`, `minor`, `cleanup`, ...) and by commits that only touch files modified by an earlier commit in the range.

## Plan

Group by component (`c++/`, `python/`, `docs/`), feature, or refactoring type. Propose squashing fix commits into their logical parent. Present a table:
1. Original commits
2. Proposed reorganization (squash / reorder / keep)
3. Suggested messages for merged commits

## Execute (after plan approval)

1. Backup branch: `git branch backup-<branch>-$(date +%Y%m%d-%H%M%S)`.
2. Create a temp branch from the parent of the first commit in the range.
3. Cherry-pick in the new order, using `--no-commit` for commits to be squashed.
4. When committing squashed changes:
   - Set `--author` to the contributor with the most relevant changes.
   - Add `Co-authored-by:` trailers for the other unique authors. Do not co-author Claude.
5. Reset the original branch to the new tip.
6. Verify: `git diff <original-tip> <new-tip>` must be empty.
7. On failure, point the user at the backup branch.
