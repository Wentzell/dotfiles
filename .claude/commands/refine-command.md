---
description: Iteratively improve a command prompt via testing
argument-hint: <command-name> <repo-path> [repo-paths...]
---

# Refine Command Prompt

Iteratively improve an existing command prompt by testing it against example repositories.

## Prerequisites

1. Verify this commands directory has a clean working directory:
   ```bash
   git status --porcelain
   ```
   If there are uncommitted changes, abort and ask the user to commit or stash them first.

2. Parse arguments:
   - First argument: command name (without `.md` extension)
   - Remaining arguments: paths to example git repositories

3. Verify the command file exists in this directory (e.g., `simplify.md`)

4. Verify each example repository:
   - Path exists and is a directory
   - Is a valid git repository
   - Has a clean working directory

5. Read and store the current command prompt content

## Iteration Loop

Initialize iteration counter to 1.

### Step 1: Create Test Branches

For each example repository at path `<repo-path>`:
```bash
# Record the original branch/commit to return to later
ORIGINAL_REF=$(git -C <repo-path> symbolic-ref --short HEAD 2>/dev/null || git -C <repo-path> rev-parse HEAD)
BASE_COMMIT=$(git -C <repo-path> rev-parse HEAD)

# Create and checkout test branch
git -C <repo-path> checkout -b refine-<command>-iter-<N>
```

Track for each repository:
- The repository path
- The original ref (branch name or commit hash)
- The base commit for diff comparison

### Step 2: Execute Command on Each Repository

Launch a sub-agent for each repository to execute the command being refined.

**Important sub-agent configuration:**
- Run sub-agents in **foreground mode** (do NOT use `run_in_background: true`) - background agents cannot prompt for permissions and will fail
- Set the working directory to the repository path

**Sub-agent task prompt should include:**
- The full command prompt content being tested
- Clear instruction to work within the repository
- Request to report: changes made, commits created, any errors encountered

**Capture from each sub-agent:**
- The full output/conversation
- The resulting changes (staged and unstaged)
- Any errors or issues encountered

If testing multiple repositories, run sub-agents sequentially (one at a time) to allow for interactive permission prompts.

### Step 3: Analyze Results

After all sub-agents complete, analyze the outcomes:

1. **Collect changes** from each repository:
   ```bash
   # All changes since base commit (committed + uncommitted)
   git -C <repo-path> diff <base-commit>

   # Commits made by the sub-agent
   git -C <repo-path> log --oneline <base-commit>..HEAD
   ```

2. **Compare across repositories:**
   - What types of changes were made?
   - Were changes consistent in style and approach?
   - Any unexpected or undesirable modifications?
   - Any failures or edge cases?

3. **Identify improvement opportunities:**
   - Instructions that were ambiguous or misinterpreted
   - Missing guidance that led to inconsistent results
   - Overly specific instructions that don't generalize
   - Missing error handling or edge cases

### Step 4: Propose Refinements

Present findings to the user:

1. **Summary per repository:**
   - Repository name
   - Key changes made (brief)
   - Quality assessment (good/problematic/failed)

2. **Cross-repository patterns:**
   - What worked well
   - What was inconsistent
   - What failed

3. **Proposed prompt modifications:**
   - Specific changes to the command file
   - Rationale for each change
   - How it addresses observed issues

4. **Ask user:**
   - Approve and apply refinements → continue to Step 5
   - Modify the proposal → adjust and re-present
   - Accept current state → exit loop, go to Cleanup
   - Abort → go to Cleanup without saving

### Step 5: Apply Refinements

1. Edit the command file with the approved changes
2. Increment iteration counter
3. Clean up test branches from this iteration:
   ```bash
   # For each repository
   git -C <repo-path> checkout <original-ref>
   git -C <repo-path> branch -D refine-<command>-iter-<N>
   ```
4. Return to Step 1 for next iteration

## Cleanup

Restore all repositories to their original state:
```bash
# For each repository
git -C <repo-path> checkout <original-ref>
git -C <repo-path> branch -D refine-<command>-iter-<N> 2>/dev/null || true
```

If refinements were applied, present the final diff of the command file:
```bash
git diff <command>.md
```

Ask user if they want to commit the changes.

## Key Principles

- **Keep prompts generic:** Avoid repo-specific hardcoding; instructions should work across varied codebases
- **Preserve intent:** Maintain the original purpose while improving clarity and robustness
- **Learn from failures:** Each failed or inconsistent result reveals prompt weaknesses
- **Iterate incrementally:** Make focused improvements rather than wholesale rewrites
- **Clean restoration:** Test branches are deleted after each iteration; original repos are unchanged

## Technical Notes

- **Sub-agent permissions:** Background sub-agents cannot prompt for permissions. Always run in foreground mode.
- **Branch naming:** Test branches use `refine-<command>-iter-<N>` to avoid conflicts and enable easy cleanup.
- **Original ref tracking:** Store both branch name (if on branch) and commit hash to handle detached HEAD states.
