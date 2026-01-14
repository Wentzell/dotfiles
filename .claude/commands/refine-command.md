# Refine Command Prompt

Iteratively improve an existing command prompt by testing it against example repositories.

**Arguments:** `${ARGUMENTS}` = `<command-name> <example-repo-path> [additional-repo-paths...]`

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

### Step 1: Create Repository Copies

For each example repository at path `<repo-path>`:
- Determine the repository name from the path
- Create an isolated copy in `/tmp/refine-<command>-iter-<N>/<repo-name>`:
  ```bash
  mkdir -p /tmp/refine-<command>-iter-<N>
  cp -r <repo-path> /tmp/refine-<command>-iter-<N>/<repo-name>
  ```

Using copies instead of worktrees ensures the original repositories remain completely unmodified.

Track all copy paths for cleanup.

### Step 2: Execute Command in Parallel

Launch a sub-agent for each repository copy to execute the command being refined:
- Change working directory to the copy
- Execute the command (invoke it as the user would)
- Capture:
  - The full output/conversation
  - The resulting `git diff` showing all changes made
  - Any errors or issues encountered

Run all sub-agents in parallel using a single message with multiple Task tool calls.

### Step 3: Analyze Results

After all sub-agents complete, analyze the outcomes:

1. **Collect diffs** from each copy:
   ```bash
   git -C <copy-path> diff HEAD
   ```

2. **Collect commits** made by the subagent:
   ```bash
   git -C <copy-path> log --oneline <original-HEAD>..HEAD
   ```

3. **Compare across repositories:**
   - What types of changes were made?
   - Were changes consistent in style and approach?
   - Any unexpected or undesirable modifications?
   - Any failures or edge cases?

4. **Identify improvement opportunities:**
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
3. Clean up current copies:
   ```bash
   rm -rf /tmp/refine-<command>-iter-<N>
   ```
4. Return to Step 1 for next iteration

## Cleanup

Remove all remaining copies:
```bash
rm -rf /tmp/refine-<command>-iter-*
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
- **Isolate testing:** Never modify original repositories; always work on copies
