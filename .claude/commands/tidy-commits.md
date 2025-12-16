Tidy up commits in the range ${ARGUMENTS}

Enter plan mode to analyze the commits and design the reorganization strategy before making any changes.

## Prerequisites
- Verify working directory is clean: `git status --porcelain`
- If there are uncommitted changes, abort and ask the user to commit or stash them first

## Analysis
- The range should include both endpoints. Determine the base commit and adjust accordingly:
  - For `A..B`: the base is A, use `A^..B` to include A
  - For `HEAD~N..HEAD`: the base is HEAD~N, use `HEAD~N^..HEAD` or `HEAD~$((N+1))..HEAD`
- List all commits with full messages: `git log --reverse --format="%H%n%s%n%b%n---" <adjusted-range>`
- For each commit, get changed files and actual diffs: `git show --stat --format="" <sha>` and `git show -p <sha>`
- Identify fix commits by:
  1. Message patterns (case-insensitive): fix, fixup, WIP, typo, minor, cleanup, etc.
  2. Commits that only modify files touched by an earlier commit in the range

## Grouping
- Analyze commit messages and actual code changes to identify logical topics
- Group commits by: component (c++/, python/, docs/), feature, or refactoring type
- Propose squashing fix commits into their logical parent

## Plan Output
Present a table showing:
1. Original commits
2. Proposed reorganization (which commits to squash, reorder, or keep)
3. Suggested commit messages for merged commits

## Execution
- After exiting plan mode, create a backup branch: `git branch backup-<branchname>-$(date +%Y%m%d-%H%M%S)`
- Execute the reorganization:
  1. Identify the base commit (parent of first commit in range)
  2. Create a temporary branch from the base
  3. Cherry-pick commits in the planned order, using `--no-commit` for commits to be squashed
  4. When committing squashed changes:
     - Use the author with the most relevant changes as the primary author (`--author`)
     - Collect all unique authors and co-authors from squashed commits
     - Add Co-authored-by trailers for contributors not listed as the primary author
  5. Do not add claude as a co-author
  6. Reset the original branch to the reorganized result
- Verify: `git diff <original-tip> <new-tip>` should be empty, confirming no code was lost
- If anything fails, provide instructions to recover using the backup branch
