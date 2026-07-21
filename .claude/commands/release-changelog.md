---
description: Prepare a release changelog (and, for TRIQS core, the porting script) for TRIQS, its core-libs, and applications
argument-hint: [<from-ref>]
effort: large
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

Prepare the `doc/ChangeLog.md` entry for the next release of the current repository. Works for TRIQS core and any core-lib (`h5`, `mpi`, `itertools`, `nda`, `cppdlr`, …) or application — they share the layout: `CMakeLists.txt` with `project(<NAME> VERSION X.Y.Z ...)`, `doc/ChangeLog.md`, `c++/` + `python/` + `test/`.

The `parse_commits` tool produces the *raw* material. Your job is to curate it into a changelog that a TRIQS **user** (not a developer) finds useful, and — for API-breaking releases — to author the migration section (and, **for TRIQS core only**, the `port_to_triqs<N>` script).

**Project type matters** — detect it from the repo name / `project(...)` and adapt:
- **TRIQS core** (`triqs`): authors `porting_tools/port_to_triqs<N>` + `doc/porting_to_triqs<N>.md` on major releases. ChangeLog uses MyST: `(changelog)=` / `# Changelog`.
- **Core-lib** (`nda`, `h5`, `mpi`, `itertools`, `cppdlr`): no porting script — API breaks are described in the highlights/migration prose only. ChangeLog header is often Doxygen-style: `@page changelog Changelog`. Symbol-heavy bullets use inline code (`` `nda::linalg::eig` ``).
- **Application** (`cthyb`, …): typically a **compatibility release for TRIQS version X.Y.Z**. Does *not* author a porting script — instead it *runs* the upstream one (a `* Run port_to_triqs<N> script for …` bullet) and *bumps the app4triqs skeleton* (a `* Use the latest app4triqs/X.Y.x skeleton` bullet).

## Arguments

- `<from-ref>` (optional) — the tag/commit the changelog starts *after*. Passed to `parse_commits -tag`.

**Choosing the base ref (do not rely on `git describe`).** On a long-lived branch like `unstable`, `git describe --tags --abbrev=0` (what `parse_commits` uses by default) returns the most recent *reachable* tag, which is often an ancient `*-rc1`, **not** the last release — release tags live on `X.Y.x` branches that aren't reachable. If `<from-ref>` is not given, derive it as follows (**most robust first**):
- **Find the commit that added the changelog's current top `## Version` entry** (the previous release): `grep -m1 '## Version' doc/ChangeLog.md` to read its `X.Y.Z`, then `git log -S "Version <X.Y.Z>" --oneline -- doc/ChangeLog.md | head -1`, and use that commit as the base. This bounds the range to "commits since the last *documented* release" and is robust even when the release tag is unreachable from `unstable` and when the `X.Y.x` branch split long before the release — the two failure modes that break the methods below.
- **Release tag (cross-check, don't trust blindly):** `git tag --sort=-v:refname | head` (pick the last *real* release, skipping rc/pre tags), then verify with `git rev-list --count <tag>..HEAD`. Use it to sanity-check the count from the method above; the tag is often unreachable from `unstable`, in which case it won't work at all.
- **First release (no tags / empty changelog stub):** there is no prior release — base on the app4triqs initialization (the `Adjust app4triqs skeleton for <app>` commit, or the first app-specific commit), and open the entry as a feature release (highlights list), not a compatibility bump.
- **Avoid `git merge-base HEAD origin/<prior>.x` as the primary method:** when the release branch split early it overshoots massively (observed 510 and 936 commits vs a correct ~90–130). Last resort only, and always verify the count.

**Confirm the resulting commit count is sane before proceeding.** If the changelog's top `## Version` entry is *older* than the latest `X.Y.x` release branch (some releases shipped without a changelog entry — seen in `ctint`), flag that gap to the user rather than assuming the changelog is authoritative for the base.

**Ensure HEAD is the release tip.** `parse_commits` is hardwired to `<from-ref>..HEAD`. If the working checkout is a feature branch, the list will wrongly include unreleased feature commits. Check out the release tip first (e.g. `git checkout origin/unstable`) or otherwise confirm HEAD is what you intend to release. **Exception — running inside `/release-app`:** the porting and app4triqs-merge commits made earlier in that pipeline are committed locally but **not yet pushed**, and they *belong* in this release. There, local `HEAD` *is* the release tip — do **not** `git checkout origin/unstable`, which would silently drop those prep commits from the range. Only reset to the pushed tip when HEAD carries *unrelated* feature work.

## Context

- Repo: !`basename "$(git rev-parse --show-toplevel)"`
- `project(...)`: !`grep -E "^project\(" CMakeLists.txt | head -1`
- Branch: !`git branch --show-current`
- Reachable tag (`git describe` — often WRONG base, see Arguments): !`git describe --tags --abbrev=0 2>/dev/null || echo "(no tag)"`
- Released versions (version-sorted): !`git tag --sort=-v:refname | head -5`
- Working tree: !`git status --porcelain | head`
- Existing porting scripts: !`ls porting_tools/ 2>/dev/null || true`
- ChangeLog header (1st non-blank line — reveals MyST vs Doxygen): !`grep -m1 . doc/ChangeLog.md 2>/dev/null`
- Prior opening sentence (to mirror tone): !`grep -m1 -iE 'is a .*release' doc/ChangeLog.md 2>/dev/null`

Determine the **target version** from the intended bump (ask the user if ambiguous): patch (`X.Y.Z+1`), minor (`X.Y+1.0`), or **major** (`X+1.0.0`). API-breaking releases (usually major) get a migration section; only TRIQS core also gets a porting script. Patch releases get neither.

## Phase 1 — Generate the raw list

From the repo root, with the base ref chosen per **Arguments** (never the bare `git describe` default on a dev branch) and HEAD confirmed as the release tip:

```bash
parse_commits -tag <base-ref> > <scratchpad>/raw-changelog.md
```

Write to your session scratchpad dir, not a fixed `/tmp` path (collision-prone on a shared workstation). This emits the contributor line (`%an` + `Co-authored-by` trailers, names normalized via the `name_filter` map, bots and Claude filtered) followed by `### <topic>` groups derived from each commit's `[topic]` prefix. Read it. This is your starting point — **never ship it verbatim.**

If the range is large (a major release, hundreds of commits), first **cluster by theme**: skim the raw list and identify the few dominant cross-cutting efforts (e.g. a binding-framework migration, a doc-pipeline switch). Each becomes *one* highlight + a short migration section, not 80 bullets. Curate the long tail afterwards. Don't attempt a purely linear bullet-by-bullet pass at this scale.

## Phase 2 — Curate (the core task)

Rewrite the raw list into a user-facing changelog. Apply, in order:

1. **Group by category/topic.** Keep `parse_commits`' `[topic]` groups where they map to a real component (`gf`, `cmake`, `mc_generic`, `det_manip`, `doc`, `jenkins`, …). Merge near-duplicate groups (e.g. `Gf`/`gf`), and fold one-off topics into `General`. Match the heading casing used in prior entries of *this* repo's `ChangeLog.md`; when a **new component** appears that has no prior heading, name it after the component in lowercase (e.g. `### c2py`, `### docker`) — don't force it into an ill-fitting old heading.
2. **De-duplicate.** Collapse multiple commits describing one logical change into a single bullet.
3. **Drop noise.** Remove WIP/fixup/intermediate commits, "address review comments", reverts-of-own-commits, merge churn, and changes later undone within the same range. **Also drop the release's own bookkeeping commits** — `Update changelog …`, `Bump/Increase version …`, `clang-format all …` — and never mine them for content (the range usually contains the in-progress changelog edits themselves, which would be circular).
4. **User relevance filter.** Keep only what a TRIQS user reading the changelog cares about: new features, behavior changes, bug fixes they could have hit, performance, build/install/compat changes, deprecations/removals. Drop purely internal refactors, test-only changes, and CI plumbing **unless** user-visible — when in doubt, demote to a terse bullet rather than deleting.
5. **Rewrite bullets** as concise, present-tense, user-oriented statements (not raw commit subjects). One line each. Wrap symbol/function/header/macro names in inline code (`` `nda::linalg::eig` ``, `` `triqs/mesh.hpp` ``) — standard across these projects, heaviest in core-libs. **Preserve trailing PR/issue numbers** like `(#163)` that `parse_commits` carried over.

**Opening paragraph** — mirror the prior entry's phrasing for *this* repo (see Context):
- Patch: "<NAME> Version X.Y.Z is a patch-release that introduces minor fixes …".
- **Application compatibility release** (the common app case): "<NAME> version X.Y.Z is a compatibility release for TRIQS version X.Y.Z …".
- Major / feature-rich: open with a `*`-bulleted highlights list of the headline changes (cf. `## Version 3.0.0` in triqs, `## Version 2.0.0` in nda), ending with "* Fixes several library issues". **For apps, "major" here means the *app's own* content is feature-rich — not merely that it tracks a major TRIQS bump.** An app release that is in substance just a TRIQS-compatibility bump (porting + skeleton update, no headline app features) keeps the **compatibility-release** opening below even though its version number bumps major; don't switch to a highlights list on the strength of the TRIQS major alone.

**Standard application practice** (apps only): mention the app4triqs skeleton update and TRIQS compatibility. **Follow the prior entry's form** — recent cthyb entries fold this into the *opening prose* ("… a compatibility release for TRIQS version X.Y.Z including an update to the latest app4triqs skeleton"), not a bullet. Add a `* Use the latest app4triqs/X.Y.x skeleton` bullet only if the repo's prior entries do. After a real TRIQS API break, add `* Run port_to_triqs<N> script for <…> changes`.

**Contributor line — verify, don't just trust `parse_commits`.** It now harvests `%an` *and* `Co-authored-by` trailers (names normalized, bots and Claude filtered), but it **cannot recover authors of squash-merged PRs** — their authorship collapses into the merger's name and is absent from git entirely. So:
- Cross-check against PRs merged in the range: `gh pr list --state merged --search "merged:>=<base-date>"` (or the project's PR history) and add any contributor the git history dropped.
- Scan the emitted line for un-normalized names: bare GitHub handles (lowercase one-word logins), all-caps surnames, or first-name/full-name variants of one person. Fix them and add the mapping to `~/bin/parse_commits` so it's permanent.
- Placement is normally right after the opening paragraph (a few older app entries put it at the end — follow the prior entry).

## Phase 3 — API breaks & migration section (major / API-breaking releases)

Detect public-API changes to drive both the migration prose and the porting regexes. Use the `/api-review ${ARGUMENTS}` command (or, lighter-weight, inspect renames/removals directly):

```bash
git log --no-merges --pretty=format:%s <base-ref>..HEAD | grep -iE 'renam|remov|deprecat|move|split|replace|breaking'
```

Verify each candidate against the actual diff — most "Rename …" commits at major-release scale touch **private** members/internals, not public API, and must not drive a migration note or porting rule.

Author dedicated `###` subsections **above** the itemized list, modeled on past major releases (triqs `## Version 3.0.0`: `### Renamings`, `### Removal of deprecated API`, `### Dependency Management`; cthyb `### Delta Interface`; nda's 2.0.0 highlights list). Each should:
- explain *why* the change happened and *what* the user must do;
- list removed/renamed symbols explicitly (C++ and Python separately), in inline code;
- **(TRIQS core only)** point to the porting script and `doc/porting_to_triqs<N>.md`.

This phase applies to **all** project types — core-libs and apps describe their migration in prose/highlights even though they ship no porting script.

## Phase 4 — Porting script (**TRIQS core only**, API-breaking releases)

Skip this phase for core-libs and applications — they don't ship a porting script (apps instead get the `* Run port_to_triqs<N> …` bullet from Phase 2). Only proceed if the repo is `triqs`.

Create `porting_tools/port_to_triqs<N>` modeled on the *structure* of `porting_tools/port_to_triqs3` (read it first) — copy its shape, not its cruft (it carries a dead `glob` import and stale commented-out rules; leave those out):

- Same structure: `repl_dict` of `old → new` (regex-capable via `re.sub`), `file_endings`, recursive `os.walk` over `os.getcwd()`, `ignore_lst`.
- Seed `repl_dict` from the renames found in Phase 3 — only changes expressible as safe regex replacements (module/header renames, symbol renames, simple signature swaps). Group entries with `# --- <topic> ---` comments as the existing script does. Use raw strings for any pattern with backslashes.
- Make it executable (`chmod +x`) and add a `### Porting Script` bullet referencing it.

Also create `doc/porting_to_triqs<N>.md` modeled on `doc/porting_to_triqs3.md`: preparation steps, what the script does, and manual steps the script can't cover. Link it from the migration section.

**Do not** put non-regex-safe changes (semantic/behavioral migrations) in the script — document those as manual steps in the guide instead.

## Phase 5 — Assemble & insert

Insert the new `## Version <target>` section **above** the previous one in `doc/ChangeLog.md`, leaving the file's top header line untouched (MyST `(changelog)=` / `# Changelog` for triqs+apps, Doxygen `@page changelog Changelog` for core-libs — see Context). Before writing, read the prior 2-3 entries and match their wording, opening sentence, and component-heading conventions exactly — these vary per project (e.g. nda uses lowercase `### blas/lapack`, `### ghactions`; triqs uses `### cmake`, `### jenkins`).

The top-level `ChangeLog.md` is usually a symlink to `doc/ChangeLog.md` — edit `doc/ChangeLog.md` (the real file). If instead they are two real copies, update both and keep them consistent.

## Phase 6 — Report

- Raw bullets in / curated bullets out (how many dropped, merged).
- Migration sections authored (if any).
- Porting script + guide created (path), or "n/a (patch release)".
- Anything you were unsure whether to keep — list it for the user to confirm.

**Leave commits to the user** (or a follow-up `/commit`); this command prepares content, it does not commit. If a porting script was generated, note that the regex set needs a real-world test pass on a downstream app before release.
