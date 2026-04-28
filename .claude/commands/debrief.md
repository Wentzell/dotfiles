---
description: Distill session learnings into memory files
effort: medium
---

Distill durable lessons from this session into the appropriate persistent file.

## Targets

1. **User-level** `~/.claude/CLAUDE.md` — generic across all projects (tools, idioms, environment)
2. **Repo-level** `CLAUDE.md` at repo root — project-specific (APIs, types, build quirks)
3. **Project memory** `~/.claude/projects/<project-path>/memory/` — contextual findings, decisions, references for this project (see auto-memory rules in user-level CLAUDE.md for file format)

## Phase 1: Gather

Read the current user-level and repo-level `CLAUDE.md` (locate repo root via `git rev-parse --show-toplevel`). Read existing project `MEMORY.md` and scan memory files to avoid duplicates. Note if repo-level `CLAUDE.md` is missing.

## Phase 2: Analyze

Review the conversation for: errors and corrections, non-obvious discoveries, workflow patterns that deviated from defaults, design decisions worth preserving.

Classify each finding into one of the three targets. Exclude content already captured, transient details (paths, hashes), obvious facts, or anything derivable from the code itself.

## Phase 3: Review and apply

Present each proposed addition diff-style — section heading and exact lines for CLAUDE.md edits, full file content for new memory files. Ask the user to approve, edit, or skip per item. Write only approved changes; do not restructure existing content.
