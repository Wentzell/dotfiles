---
name: publish-deb-repo
description: Publish the TRIQS Debian/apt repository under ~ccq/public_www from the artifacts of a packaging release-branch Jenkins build
argument-hint: [<series>] [<build>]
effort: high
allowed-tools: Bash, Read, Glob, Grep, mcp__jenkins-fi__getJob, mcp__jenkins-fi__getBuild
disable-model-invocation: true
---

Refresh the public apt repository at `https://users.flatironinstitute.org/~ccq/triqs<MAJOR>/<codename>/`
with the packages built by `CCQ/TRIQS/packaging/<series>` on Jenkins.

Jenkins already does all the work: its `<platform> pkgs` stage runs `apt-ftparchive` and signs the
result, then archives the finished repository as a flat `<codename>.tgz`. **Publishing is therefore
download, verify, swap into place — nothing more.** This skill never rebuilds a package, never
re-runs `apt-ftparchive`, and never re-signs — the signing key exists only as the Jenkins
`triqs-packaging-key` credential, so anything regenerated locally would be unsigned or would no
longer match `InRelease`.

It **mutates a world-visible resource**: the moment the files land, every user's next
`apt-get update` sees them. Phases 1–3 are read-only; Phase 4 is gated on explicit approval.

Two bundled scripts do everything that must not go wrong — `scripts/fetch-verify.sh` (Phase 2) and
`scripts/publish.sh` (Phase 4). Both are bash; see "Two things about the shell you run in".

## Arguments

`$ARGUMENTS`: `[<series>] [<build>]`
- **`<series>`** — packaging release branch, e.g. `4.0.x`. Default: the highest `X.Y.x` branch in
  the packaging repo (see Context). `unstable` is never published — the public repos only carry
  release branches.
- **`<build>`** — Jenkins build number, or `lastStableBuild` (default). **`lastSuccessfulBuild` is
  rejected by the script**, not merely discouraged: Jenkins counts UNSTABLE as successful, and
  `archiveArtifacts` runs *before* the test stages, so that ref can hand you the debs of a build
  whose test suites failed. `<series>` must match `X.Y.x` and `<build>` a number or
  `lastStableBuild` — both end up in URLs and paths, so they are constrained before either is
  built.

Destination is derived from the series' major version: `4.0.x` → `/mnt/home/ccq/public_www/triqs4/`.
(The top-level `triqs -> triqs2` symlink is legacy; leave it alone.)

This skill is written against the 4.0.x-era pipeline (`jenkins/Jenkinsfile`, `<codename>.tgz`
artifacts). Series ≤ 3.3.x used a different root `Jenkinsfile` and the `gpg-sign-key` credential —
check the artifact names before assuming this flow applies.

## Context

- Packaging repo: !`ls -d ~/Dropbox/Coding/packaging 2>/dev/null || echo "(not checked out — clone it, its public.gpg is the trust anchor)"`
- Release branches: !`git -C ~/Dropbox/Coding/packaging branch -r --format='%(refname:short)' 2>/dev/null | sed 's|origin/||' | grep -E '^[0-9]+\.[0-9]+\.x$' | sort -V | tr '\n' ' '`
- Currently published: !`for d in /mnt/home/ccq/public_www/triqs[0-9]*/; do printf '%s: ' "$(basename $d)"; for p in $d*/; do [ -f "$p/Packages" ] && printf '%s(triqs %s, %s) ' "$(basename $p)" "$(awk '/^Package: triqs$/{f=1} f&&/^Version:/{print $2;exit}' $p/Packages)" "$(date -r $p/Packages +%F)"; done; echo; done`
- Destination perms (the dirs Phase 4 replaces): !`ls -ld /mnt/home/ccq/public_www/triqs[0-9]*/*/ 2>/dev/null | awk '{print "  "$1" "$3":"$4" "$NF}'`
- You are in group `ccq`: !`id -nG | tr ' ' '\n' | grep -qx ccq && echo yes || echo "NO — you will not be able to hand the tree to the ccq group"`

Free space is deliberately **not** probed: `df` reports the whole shared GPFS filesystem, not the
capacity/inode quota on `~ccq`, which is not readable from a workstation. Assume the quota can be
hit mid-write; that is what Phase 4's ordering is designed to survive.

## Two things about the shell you run in

**It is zsh, and `set -e` does not work there.** Verified: `( set -e; false; echo reached )` prints
`reached` and returns 0. Any inline snippet that looks like it aborts on the first failure does not.
This is why **everything destructive lives in the bundled `#!/bin/bash` scripts** and is invoked as a
program — `bash script.sh` does abort correctly. Do not inline the publish steps, and do not trust a
`set -euo pipefail` line pasted into a Bash call. The inline blocks below are read-only.

zsh also does not word-split unquoted parameters, so `for p in $PLATFORMS` iterates **once** over
`"noble resolute"`. Glob the stage directory instead of splitting a string.

**Each Bash call is a fresh environment.** A variable set in Phase 2 is gone by Phase 3. So use a
**deterministic** stage path and re-declare this at the top of every block:

```bash
SERIES=4.0.x BUILD=2
MAJOR=${SERIES%%.*}
SKILL=~/.claude/skills/publish-deb-repo
STAGE=/tmp/triqs-pub-$SERIES-$BUILD          # or the session scratchpad — same path every block
```

## Phase 1 — Pick the build

Resolve the series, then query Jenkins with the `jenkins-fi` MCP server (`/jenkins` covers its use):

```
mcp__jenkins-fi__getJob  jobFullName=CCQ/TRIQS/packaging/<series>
                         tree=lastStableBuild[number,result,timestamp],lastSuccessfulBuild[number,result],lastBuild[number,result,building]
```

Report the build number, result, and age. Stop and ask if:

- **`lastStableBuild` is behind `lastSuccessfulBuild`** — the newest build went UNSTABLE. Say so
  explicitly; publishing it is a deliberate call (`ALLOW_UNSTABLE=1` in Phase 2), never a default.
- the build is **older than ~30 days** — see Gotchas on retention.
- the job's **last build is still running** — its artifacts may be a half-populated matrix.

## Phase 2 — Fetch and verify (read-only)

```bash
"$SKILL/scripts/fetch-verify.sh" "$SERIES" "$BUILD" "$STAGE"
```

Downloads ~65 MB per platform, ~130 MB staged for a two-platform series. It refuses a non-empty
stage directory, and **hard-fails** — no warnings to read past — unless:

- the build is finished, and is `SUCCESS` — or exactly `UNSTABLE` with `ALLOW_UNSTABLE=1`.
  `FAILURE` and `ABORTED` are not publishable, override or not;
- the commit Jenkins built is present in the local packaging repo, and Jenkins reported it as a
  literal 40-hex SHA1 — git would equally accept `HEAD` or a tag, and the trust anchor and the
  provenance table would then come from a tree Jenkins never built. Everything downstream reads
  that commit rather than the branch tip, so a missing one is a hard stop with the `git fetch` to
  run, not a skipped check;
- the alias is resolved **once**. `lastStableBuild` names the metadata request only; every artifact
  is then fetched from `<job>/<resolved-number>/artifact/`, so a build going stable during the
  ~40 s download cannot pair one build's debs with another's identity, commit, and matrix;
- the archived platform set equals the matrix that commit's Jenkinsfile declares, so a stage that
  timed out cannot masquerade as a dropped codename. Reformatting that list in the Jenkinsfile
  would otherwise deadlock a release, so `ALLOW_MATRIX_SKIP=1` exists — confirm the matrix by hand
  before using it. Artifact names must also look like codenames (`^[a-z][a-z0-9-]*$`);
- every tarball member is a regular file with an expected name. Checked in **three** ways: member
  *types* by listing the archive before extraction, the only place a hard link or device node is
  still visible; member *count* against the files that landed, which is how a duplicate is caught
  without parsing names, since `./x`, `/x` and `.//x` are three spellings `tar` collapses onto one
  path so the second silently overwrites a member already accepted; and the *names* that actually
  landed, which catches the absolute path `tar` rewrites into a subdirectory. Nothing keys off the
  name as `tar -tv` prints it — that column cannot be split reliably;
- the **trust anchor is read out of the commit** (`git show <build-sha>:public.gpg`), not from the
  worktree, so a dirty checkout cannot substitute a key; it must be the only key in that file, and
  each tarball's bundled `public.gpg` must equal it;
- **both** `InRelease` *and* the detached `Release`/`Release.gpg` pair carry a `VALIDSIG` whose own
  fingerprint field is the anchor's, gpg exits zero, and no
  `BADSIG`/`ERRSIG`/`EXPSIG`/`EXPKEYSIG`/`REVKEYSIG`/`KEYREVOKED`/`KEYEXPIRED` appears. Matching
  `VALIDSIG` loosely is not enough — gpg emits it *alongside* `EXPKEYSIG`;
- the clear-signed `InRelease` payload is byte-identical to `Release`. apt consumes `InRelease`
  while every checksum below is read from `Release`; nothing else ties the two together;
- `Release` checksums `Packages{,.gz,.bz2}`, **and** both compressed indices decompress to exactly
  `Packages` — apt may fetch any of the three;
- `Packages` parses cleanly **by stanza**: exactly one `Filename` and one `SHA256` each, no
  duplicates, and a filename that is a plain basename (a line-by-line pairing silently skips a
  stanza missing one of them while still counting it as verified);
- every indexed `SHA256` matches its `.deb`, and the indexed set and the files on disk agree in
  **both** directions.

Any failure is fatal — do not repair the staged tree by hand. Re-pull, or go back to Jenkins.

It then prints a **provenance table**: each package's deb version beside its submodule's tag at the
commit Jenkins built, joined for you (the index lower-cases package names, the submodules don't).
On a release branch every row should read `ok`.

Only after all of that does it write `$STAGE/.verified`, which is what `publish.sh` requires — the
`.build.env` it writes early is working state, not evidence. It also records the tarball checksums,
so Phase 4 can confirm nothing swapped the stage out from under it.

## Phase 3 — Diff and approval

```bash
for d in "$STAGE"/*/; do
  p=$(basename "$d")
  echo "== $p"
  diff <(grep -E '^(Package|Version):' "/mnt/home/ccq/public_www/triqs$MAJOR/$p/Packages" 2>/dev/null | paste - -) \
       <(grep -E '^(Package|Version):' "$d/Packages" | paste - -) || true
done
```

`diff` exits 1 whenever anything changed, which is the normal case; for a brand-new codename the
left-hand side does not exist and everything reads as added.

Present: build identity and source commit, the provenance verdict from Phase 2, per-package version
changes, packages added or **dropped**, the platforms about to be touched, and any published
codename absent from this build — those stay frozen and untouched.

**Get explicit approval before Phase 4.** A version *downgrade*, a shrinking package set, or a
provenance row that isn't `ok` are stop-and-ask conditions, not warnings to publish through.

## Phase 4 — Publish

```bash
DRY_RUN=1 "$SKILL/scripts/publish.sh" "$SERIES" "$STAGE"      # rehearse
"$SKILL/scripts/publish.sh" "$SERIES" "$STAGE"                # commit
```

Named platforms can follow the stage dir; the default is every platform the stage was verified for,
and it refuses any other. It also refuses a stage without `.verified`, a `<series>` that disagrees
with the one recorded there, a series with no numeric major version, and a destination that is a
symlink — `public_www/triqs -> triqs2` is exactly the trap that last one closes.

`DRY_RUN=1` prepares every tree, diffs each against the stage, and removes them again without
swapping. It is not perfectly inert: it creates `$SERVE_ROOT` and `$SERVE`, takes the lock, and
writes each prepared tree under `$SERVE` for as long as it exists. Nothing live is replaced and no
backup root is created.

`SERVE_ROOT`/`BACKUP_ROOT`/`REPO_GROUP` exist so the script can be exercised against a sandbox.
Overriding `SERVE_ROOT` marks the run sandboxed — resolved with `realpath`, so a trailing slash
cannot make a live publish look rehearsed — which also defaults `BACKUP_ROOT` alongside it and
skips the HTTP post-flight, since that could only ever see the real server. Leave them unset in
anger.

**Every platform is prepared and diffed before any is swapped**, so a quota or permission failure
on the last one cannot leave the matrix half updated. Then, per platform:

- **Prepares alongside, then does two renames.** `InRelease` sits near the *front* of the tarball,
  so an in-place extract briefly serves a valid signed index pointing at debs that do not exist yet
  — and an interrupted run leaves it that way permanently. The second rename is within `$SERVE`;
  the first moves the old tree *out* to `$BACKUP`, a different directory on the same filesystem —
  still an atomic `rename(2)`, but it would silently degrade to a slow copy if `BACKUP_ROOT` ever
  moved off `/mnt/home/ccq`.
- **`chgrp ccq` + `755`/`644`.** `tar` would otherwise leave the tree in the publisher's own group.
  Group-**readable**, deliberately not group-writable: a published index is signed, and nothing
  should be able to overwrite it outside this script — `triqs2`/`triqs3` are group-writable only
  because they predate it. Republishing is a re-run here, not a hand edit, so nobody needs write
  access to the live tree.
- **Diffs the prepared tree against the verified stage before the swap, and the live tree after.**
  That second diff is what catches a deb truncated by a quota failure — the signature and index
  alone would not, since the small early files survive intact.
- **Backs up to `/mnt/home/ccq/.triqs-deb-backups/`** — outside `public_www`, so the rollback copy is
  not a second publicly fetchable signed apt repo the way a `<codename>.prev/` beside the live tree
  would be. Same filesystem, so the rename is still instant.
- **Never overwrites an existing rollback copy, and skips a platform already identical to the
  stage.** Re-running after a scare is the likeliest thing an operator does, and a naive re-run
  would move the *just-published* tree into `.prev`, quietly destroying the only copy of the
  release you would roll back to. Instead it reports "already published" and does nothing, or —
  if the live tree has genuinely changed — refuses and tells you to roll back or move `.prev`
  aside first. Both decisions are made in the **prepare** pass, so a `.prev` conflict on the last
  platform cannot surface only after the first is already live. The refusal reads the state it
  actually finds: if the codename is *missing* rather than live, it says the previous run was
  interrupted mid-swap and tells you to move `.prev` back — never to delete it.
- **Holds `flock` across the whole run**, beside the tree it guards rather than beside the backups,
  so two real runs always contend and a sandboxed one never does. Jenkins serialises its side with
  `disableConcurrentBuilds()`; this side otherwise has nothing.
- **Runs the HTTP post-flight itself** once everything is swapped: `InRelease` re-verified over the
  wire against the staged keyring by `VALIDSIG` rather than by grepping English gpg output, and a
  HEAD for *every* indexed deb — a spot check can pass on a file unchanged since the previous
  release and tell you nothing about this one.

On failure the script cleans up after itself and says what it did: prepared-but-unswapped trees are
removed, and if it died in the window between the two renames — with the codename moved out and
nothing yet moved in — the EXIT handler moves the backup back and prints `RECOVERED`. Platforms
swapped *earlier in the same run* stay swapped; they are listed under `published this run`, with
their rollback commands, on every exit path including the failing ones. A platform counts as
published from the moment its rename lands, before the post-swap diff — if that diff is what
failed, the tree is live either way and you need its rollback line more, not less.

It traps `INT` and `TERM`, not just `EXIT`. Bash runs an `EXIT` handler the instant a fatal signal
arrives, orphaning the `mv` still in flight; the explicit traps defer it to a command boundary and
give the handler a truthful `$?`. Ctrl-C during a swap therefore prints `RECOVERED` and exits 130
rather than leaving a codename missing and a log that simply stops.

A post-flight failure is different again: the swap already succeeded and the local trees already
matched, so it points at the web server. The script says so, distinguishes a server error from a
transient one, and **exits non-zero** — do not read that exit code as a failed publish. Investigate
before rolling back; re-running is safe, since it refuses rather than clobbering the backup.

## Phase 5 — Close out

The script's post-flight covers the repository itself. Two things remain:

- If a container runtime is available, the real end-to-end check is one `apt` run in a clean
  `ubuntu:<version>` image against the sources line from the triqs `doc/install.rst`:
  `deb https://users.flatironinstitute.org/~ccq/triqs<MAJOR>/<codename>/ /`
- Once satisfied, drop the backups: `rm -rf /mnt/home/ccq/.triqs-deb-backups/triqs<MAJOR>` — `~ccq`
  is quota'd and each is ~33 MB per platform.

## Gotchas

- **`lastSuccessfulBuild` is the wrong ref.** `archiveArtifacts` runs in the `<platform> pkgs`
  stage, *before* the test stages, and every test module is wrapped in
  `catchError(buildResult: 'UNSTABLE')`. Jenkins counts UNSTABLE as "successful". Use
  `lastStableBuild` (SUCCESS only) or a pinned number.
- **Never regenerate the index locally.** No local `apt-ftparchive`, no re-signing. Only Jenkins has
  the key. If a destination and its index ever disagree, re-pull the tarball.
- **Superseded debs left in place become unreachable.** The `Packages` index lists only the build
  that produced it, so anything else in the directory is dead weight — `triqs3/noble` holds 32 debs
  and indexes 11. Phase 4 replaces the directory wholesale rather than extracting into it.
- **Dropped platforms stay frozen.** `triqs3` still serves `bionic` 3.0.2 and `focal` 3.1.1 beside
  `jammy`/`noble` 3.3.1. Publish only the codenames in the build's artifact list, and never delete
  the others.
- **A new codename is more than a directory.** `doc/install.rst` in triqs names the supported LTS
  versions and builds the URL from `$DISTRIB_CODENAME`, so the directory name must be exactly the
  Ubuntu codename, and the docs need a matching update.
- **Flat repo.** `apt-ftparchive release` is called without a config, so `Release` carries only
  `Date` and checksums — no `Origin`/`Suite`/`Codename`. Hence the flat sources line `deb <url>/ /`.
  Don't "improve" this without changing the docs users have already followed.
- **Retention** is `numToKeepStr: '10', daysToKeepStr: '30'` — build retention, not just artifacts.
  Jenkins' `LogRotator` does not discard the last stable or last successful build, so
  `lastStableBuild` should outlive 30 days; any *other* older build may be gone. Unverified here
  (`4.0.x` has only two builds), so if you need a specific older build, confirm its artifacts still
  exist before planning around it.
- **`curl` is blocked on this workstation** — use `wget`, with `--no-netrc` to suppress the
  unreadable-`~/.netrc` warning.
- **Directory listings** come from an empty `index.autorec` marker, which `triqs2/` and `triqs3/`
  carry at their top level and `triqs4/` does not: `~ccq/triqs3/` returns a generated browsable
  listing, `~ccq/triqs4/` returns 403. Individual files are served either way, so apt is unaffected.
- **install.rst's recipe is stale** independently of any publish: it uses the deprecated
  `apt-key add`, which is gone on current Ubuntu. Dropping the key into `trusted.gpg.d/triqs.gpg`
  is not the fix either — `public.gpg` is ASCII-armored, and apt rejects that there as "an
  unsupported filetype", then reports the repo as unsigned. It must be dearmored, or named `.asc`.
  This recipe is verified against a clean `ubuntu:24.04` and the live repo:
  ```bash
  curl -fsSL https://users.flatironinstitute.org/~ccq/triqs4/<codename>/public.gpg \
    | gpg --dearmor -o /etc/apt/keyrings/triqs.gpg
  echo "deb [signed-by=/etc/apt/keyrings/triqs.gpg] \
    https://users.flatironinstitute.org/~ccq/triqs4/<codename>/ /" > /etc/apt/sources.list.d/triqs.list
  ```

## Report

- Series, build number + result + date, source commit.
- Per platform: packages published, versions changed, and the provenance verdict.
- Post-flight: signature over HTTP and whether every indexed deb was fetchable.
- Whether the tree came out `ccq`-owned at `755`/`644`, and whether backups still exist (with path).
- Follow-ups, if any: a new codename needs `doc/install.rst` updated in the triqs repo; an UNSTABLE
  build needs its failing tests triaged (`/jenkins <series>`).
