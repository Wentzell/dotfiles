---
description: Distill session learnings into memory files
---

Distill actionable lessons from this session into persistent memory files.

## Memory Targets

1. **User-level** (`~/.claude/CLAUDE.md`): Generic lessons applicable across all projects (tools, workflow, environment, language idioms)
2. **Repo-level** (`CLAUDE.md` at repository root): Lessons specific to this project (APIs, types, build quirks, test patterns)

## Phase 1: Gather

Read the current contents of both memory files:
- `~/.claude/CLAUDE.md`
- The repo-level `CLAUDE.md` (locate via `git rev-parse --show-toplevel`)

If the repo-level `CLAUDE.md` does not exist, note that it will be created.

## Phase 2: Analyze

Review the full conversation for:

- **Errors and corrections**: Mistakes made, wrong assumptions, failed approaches
- **Non-obvious discoveries**: API quirks, hidden dependencies, workarounds
- **Workflow patterns**: Build commands, test invocations, toolchain specifics that deviated from defaults
- **Design decisions**: Rationale for choices that future sessions should respect

Classify each finding as:
- **Generic** (user-level): Applies to any project (e.g., tool usage, C++ idioms, environment facts)
- **Repo-specific**: Tied to this codebase (e.g., specific types, API behavior, build setup)

Exclude:
- Information already present in either memory file
- Transient details (temporary paths, specific commit hashes)
- Obvious facts that any session would know

## Phase 3: Draft

Format entries matching existing file conventions:

**Repo-level CLAUDE.md:**
- Add to the most appropriate existing `##` section, or create a new one if none fits
- Each entry: one concise, actionable bullet point
- Match the style and tone of existing entries

**User-level `~/.claude/CLAUDE.md`:**
- Add to the most appropriate existing section
- Match the terse, directive style (e.g., `- Use X for Y`)
- Do not restructure or rewrite existing content

If there are no findings for a given level, skip it entirely.

## Phase 4: Review

Present proposed changes for approval:
- For each memory file, show the section heading and the exact lines to be added
- Use diff-style formatting so additions are clearly visible
- Ask the user to **approve**, **edit**, or **skip**

## Phase 5: Apply

Write only the approved changes. Do not modify any content outside the approved additions.
