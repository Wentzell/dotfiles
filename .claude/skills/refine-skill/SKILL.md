---
name: refine-skill
description: Iteratively improve a skill prompt via testing
argument-hint: <skill-name> <repo-path> [repo-paths...]
disable-model-invocation: true
---

Iteratively improve an existing skill prompt by running it against example repositories and refining based on observed outcomes.

## Prerequisites

- Parse args: first = skill name (the directory name under `~/.claude/skills/`, no `/SKILL.md`), rest = paths to example git repos.
- The target is `~/.claude/skills/<skill>/SKILL.md`. Verify it exists, and that each repo path exists, is a git repo, and has a clean working tree.
- `~/.claude/skills` is a symlink into the dotfiles repo; that repo's working tree must be clean for `.claude/skills/<skill>/` (`git -C ~/dotfiles status --porcelain .claude/skills/<skill>`); abort if not.
- Read and store the current skill content, including any `references/*.md` or `scripts/*` bundled alongside it — a refinement may need to touch those rather than `SKILL.md`.

## Iteration loop

Initialize iteration counter `N = 1`.

### 1. Create test branches

For each repo:
```bash
ORIGINAL_REF=$(git -C <repo> symbolic-ref --short HEAD 2>/dev/null || git -C <repo> rev-parse HEAD)
BASE_COMMIT=$(git -C <repo> rev-parse HEAD)
git -C <repo> checkout -b refine-<skill>-iter-<N>
```
Track `(repo, ORIGINAL_REF, BASE_COMMIT)` for each.

### 2. Run the skill on each repo

Launch one sub-agent per repo with the full skill content, working directory set to the repo path, asked to report changes made, commits created, and any errors.

Sub-agents must run in **foreground**, sequentially — background agents can't prompt for permissions and will fail on interactive approvals.

Capture per-agent: full output, resulting changes (staged + unstaged), errors.

### 3. Analyze

For each repo:
```bash
git -C <repo> diff <BASE_COMMIT>
git -C <repo> log --oneline <BASE_COMMIT>..HEAD
```

Compare across repos: types of changes made, consistency of style/approach, unexpected modifications, failures or edge cases. Identify ambiguous instructions, missing guidance, over-specific instructions that didn't generalize, and missing error/edge-case handling.

### 4. Propose refinements

Present:
1. Per-repo summary — name, key changes, quality (good/problematic/failed).
2. Cross-repo patterns — what worked, what was inconsistent, what failed.
3. Proposed prompt edits — specific changes with rationale.

Ask the user to: approve and apply → step 5; modify the proposal; accept current state → cleanup; abort → cleanup without saving.

### 5. Apply

Edit `~/.claude/skills/<skill>/SKILL.md` (or the bundled reference/script the finding points at)
with approved changes, then for each repo:
```bash
git -C <repo> checkout <ORIGINAL_REF>
git -C <repo> branch -D refine-<skill>-iter-<N>
```
Increment `N`, return to step 1.

## Cleanup

Restore each repo to its `ORIGINAL_REF` and delete the iteration branch (`branch -D ... 2>/dev/null || true`).

If anything was applied, show the final `git -C ~/dotfiles diff .claude/skills/<skill>/` and ask
whether to commit.

## Principles

- **Generic prompts** — no repo-specific hardcoding; instructions should work across varied codebases.
- **Preserve intent** — improve clarity and robustness, don't change purpose.
- **Incremental** — focused edits per iteration, not wholesale rewrites.
- **Branch naming** `refine-<skill>-iter-<N>` to avoid collisions and simplify cleanup.
- **Right file** — instructions that are a lookup rather than a step belong in `references/`, not in a
  longer `SKILL.md`; `SKILL.md` stays in context all session once invoked.
- Track both branch name *and* commit hash for `ORIGINAL_REF` to handle detached HEAD.
