---
description: Distill session learnings into memory files
model: sonnet
effort: medium
---

Distill actionable lessons from this session into persistent memory files.

## Memory Targets

1. **User-level** (`~/.claude/CLAUDE.md`): Generic instructions applicable across all projects (tools, workflow, environment, language idioms)
2. **Repo-level** (`CLAUDE.md` at repository root): Instructions specific to this project (APIs, types, build quirks, test patterns)
3. **Project memory** (`~/.claude/projects/<project-path>/memory/`): Contextual findings, decisions, and references for this project

## Phase 1: Gather

Read the current contents of the instruction files:
- `~/.claude/CLAUDE.md`
- The repo-level `CLAUDE.md` (locate via `git rev-parse --show-toplevel`)

If the repo-level `CLAUDE.md` does not exist, note that it will be created.

Also check for existing project memory:
- Read `MEMORY.md` in the project memory directory (if it exists)
- Scan existing memory files to avoid duplicates

## Phase 2: Analyze

Review the full conversation for:

- **Errors and corrections**: Mistakes made, wrong assumptions, failed approaches
- **Non-obvious discoveries**: API quirks, hidden dependencies, workarounds
- **Workflow patterns**: Build commands, test invocations, toolchain specifics that deviated from defaults
- **Design decisions**: Rationale for choices that future sessions should respect

Classify each finding as:
- **Generic instruction** (user-level CLAUDE.md): Applies to any project (e.g., tool usage, C++ idioms, environment facts)
- **Repo instruction** (repo-level CLAUDE.md): Instruction for this codebase (e.g., specific types, API behavior, build setup)
- **Project note** (memory file): Contextual finding, pending task, decision, or reference for this project

Exclude:
- Information already present in either CLAUDE.md or existing memory files
- Transient details (temporary paths, specific commit hashes)
- Obvious facts that any session would know
- Code patterns, file paths, or project structure derivable from the code itself

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

**Project memory files:**
- For each project note, draft a `.md` file with frontmatter:
  ```markdown
  ---
  name: <descriptive name>
  description: <one-line summary used for relevance matching>
  type: <user|feedback|project|reference>
  ---

  <memory content>
  ```
- For `feedback` and `project` types, structure as: rule/fact, then **Why:** and **How to apply:** lines
- Draft a one-line entry for `MEMORY.md`: `- [Title](filename.md) -- one-line hook`

If there are no findings for a given target, skip it entirely.

## Phase 4: Review

Present proposed changes for approval:
- For each CLAUDE.md file, show the section heading and the exact lines to be added
- For each memory file, show the full file content
- Use diff-style formatting so additions are clearly visible
- Ask the user to **approve**, **edit**, or **skip**

## Phase 5: Apply

Write only the approved changes. Do not modify any content outside the approved additions.
- For CLAUDE.md files: edit in place
- For memory files: create the file and add its entry to `MEMORY.md`
