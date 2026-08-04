# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles for the user's dev environment on the Flatiron CCQ cluster. Files at the repo root mirror their target paths under `$HOME` and are deployed by symlinking — i.e. `~/.zshrc`, `~/.tmux.conf`, `~/bin`, etc. are symlinks back into this repo. **Editing a file here edits the live config; editing the file via its `~/...` path edits this repo.**

A few targets that also hold tool-managed runtime state (`~/.claude`, `~/.codex`, `~/.config/nvim`) are *not* whole-directory symlinks — each is a real directory at `$HOME`, populated with per-entry symlinks into this repo for the tracked config files only. Runtime state (auth tokens, session transcripts, history, caches) stays outside the repo working tree.

The default branch is `master` (not `main`) and is the working branch — there is no PR/feature-branch workflow for this repo.

## Deploying changes

`./link.sh` is the deploy script. It is **destructive**: for every top-level entry except a hard-coded exclusion list, it `rm -rf`s the existing `$HOME/<name>` and replaces it with a symlink into the repo. Do not run it casually on a populated home directory.

The exclusion list covers `.config`, `.claude`, and `.codex` — these are handled at the bottom of the script via per-entry loops (so runtime state at `$HOME/.claude` and `$HOME/.codex` survives a re-run, and `.config/nvim` is the only `.config/` entry deployed). Adding a new tracked entry under any of these dirs requires updating the corresponding loop in `link.sh`.

`$HOME/.codex/skills` needs a second level of the same treatment: it must stay a real directory because Codex keeps its own bundled skills in `$HOME/.codex/skills/.system/`, so `link.sh` symlinks each skill *individually* out of `.claude/skills/`. New skills are picked up by that loop automatically. `$HOME/.claude/skills`, by contrast, holds no runtime state and is a plain whole-directory symlink.

## Submodules

After cloning, run `git submodule update --init --recursive`. Submodules: `.oh-my-zsh`, `.solarized/dircolors-solarized`, `.jupyter/nbextensions/vim_binding`, `.vim/autoload/vim-plug`, `.config/nvim`.

## Gitignore quirks (important when adding files)

- The user's global excludes file is `~/.glob_git_ignore` (set via `core.excludesfile`), and it ignores `CLAUDE.md`, `AGENTS.md`, and `.claude` among others. Tracking any file with one of those names — e.g. this repo's root `CLAUDE.md`, or `.codex/AGENTS.md` — requires `git add -f`.
- This repo's `.gitignore` lists `bin/*` (mixed dir of tracked helpers and untracked scratch scripts on `$PATH`). Tracked files there stay tracked and editable; **new** files in `bin/` require `git add -f` to stage.

## Layout notes

- `.claude/` — user-global Claude Code config (deployed per-entry into `~/.claude/`). `.claude/skills/<name>/SKILL.md` are the user-global skills, each invocable as `/<name>` (see below); `.claude/CLAUDE.md` is the user's global CLAUDE.md loaded on every project; `.claude/settings.json` defines hooks, permissions, and env vars; `.claude/hooks/tmux-status.sh` powers the per-window tmux status dot; `.claude/statusline.sh` is the statusline command.
- `.claude/skills/` — shared by **both** agents: Claude Code reads `~/.claude/skills/`, Codex reads `~/.codex/skills/`, and `link.sh` points both at this one directory. Consequences for authoring:
  - Codex **requires** `name:` in the frontmatter (Claude Code treats it as an optional display label and derives the command from the directory name), so every `SKILL.md` here carries one, matching its directory.
  - The directory name *is* the command name in Claude Code. There is no directory-namespacing as there was under the old `commands/` layout — a subdirectory there became a `/prefix:name` command, which is how a stray `commands/bkp/` once shipped as a live `/bkp:refine-command`. Group by name prefix (`release-*`) instead, and don't park backups in here.
  - Skills replace what used to live in `.claude/commands/*.md`. Commands still work but are the legacy path; per the [docs](https://code.claude.com/docs/en/skills) they "have been merged into skills," and only skills support bundled supporting files.
  - **Every skill sets `disable-model-invocation: true`, and new ones should too.** Skills here are invoked deliberately with `/<name>`, never auto-activated by Claude. This also keeps their descriptions out of context entirely, so the whole set costs nothing until used. Dropping the flag on a new skill is a deliberate exception, not the default.
  - Detail that's a lookup rather than a step belongs in `references/*.md`, and executable tooling in `scripts/` addressed as `${CLAUDE_SKILL_DIR}/scripts/…` — both load only when needed, whereas `SKILL.md` itself stays in context for the whole session once invoked. `semantic-scholar/scripts/s2lit.py` is the reference case: it used to be a 266-line Python program pasted inside the prompt.
- `.codex/` — OpenAI Codex CLI config (deployed per-entry into `~/.codex/`). `.codex/config.toml` is the main config; `.codex/AGENTS.md` is an internal symlink to `.claude/CLAUDE.md` so global instructions are shared between the two agents. Codex reaches the skills two independent ways:
  - `~/.codex/skills/` — the per-skill loop in `link.sh`, covering all 19. This is the mechanism Codex actually documents.
  - `.codex/prompts/<name>.md` — a repo-side symlink per skill, pointing at `../../.claude/skills/<name>/SKILL.md`, deployed as a whole-directory link. A deliberate belt-and-braces fallback in case Codex doesn't traverse symlinks when discovering skill directories. Only the **16 self-contained** skills are linked: `merge-app4triqs`, `migrate-to-c2py`, and `semantic-scholar` are excluded because their bodies point at `references/`/`scripts/` paths that resolve only through the skills mechanism, so a prompt link would hand Codex instructions referencing files it can't find. Adding a supporting file to a currently-linked skill means dropping its prompt link.
  - Two consequences: the YAML frontmatter renders as literal text in a Codex prompt (harmless, and true of the old `commands/` symlink too), and if skills discovery *does* work, those 16 appear twice in Codex's `/` menu. Drop `.codex/prompts` once skills discovery is confirmed if the duplication bothers you.
- `bin/` — personal helper scripts on `$PATH` (added in `.zprofile`):
  - `build_*.sh` — from-source builds for GCC, LLVM, neovim, vim, boost, kokkos, libcxx-msan, scinumpy+MKL; each installs to `~/opt/<name>`.
  - `gen_copyright` — rewrites GPL/Apache copyright headers on C++/Python/CMake files using `git blame -w -M --incremental`. Has TRIQS-specific author/years special cases. **Edits files in place.** Invoke as `gen_copyright -license Apache-Minimal -project <name> file1 file2 ...`.
  - `tmux-next-agent` — used by `.tmux.conf` (`prefix o` / `prefix u`) to cycle between tmux panes running Claude Code or Codex CLI.
  - `parse_commits`, `mkdiag.sh`, `mymake.sh`, `pymake`, `setup_venv.sh`, `triqs_setup.sh`, `fixbb.sh`, `2to3_nb`.
- `.shrc` — shared shell aliases and functions sourced from `.zshrc`. Contains `tmuxdev` (sets up the user's standard 16-window TRIQS tmux layout with `gcc` / `san` / `prof` / `dbg` build envs pre-sourced), `cmakedd`, `prof` / `pprint` / `hprof` / `hpprint` (gperftools wrappers), and slurm/cluster aliases (`interactive`, `sls`, `cluster_usage`).
- `.zprofile` defines `addlib` / `addpath` / `addenv` helpers used to extend `CPLUS_INCLUDE_PATH`, `LD_LIBRARY_PATH`, `LIBRARY_PATH`, `PKG_CONFIG_PATH`, `PATH`, and `MANPATH` consistently for software in `~/opt`.
- `.zshrc` ends with `_tmux_auto_rename`, a `chpwd` hook that renames tmux windows 1–8 to the current git repo's basename (or "Coding" outside a repo).

## When editing shell/tmux/vim configs

Changes are live for *new* shells/sessions only. The user's existing tmux server and shells will not pick up edits to `.tmux.conf`, `.zshrc`, `.zprofile`, etc. until reloaded (`tmux source-file ~/.tmux.conf`, `exec zsh`, etc.) — point this out rather than assuming a change has taken effect.
