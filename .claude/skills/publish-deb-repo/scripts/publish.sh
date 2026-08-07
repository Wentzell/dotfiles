#!/bin/bash
# Swap verified staged trees into the live TRIQS apt repository.
#
#   publish.sh <series> <stage-dir> [platform ...]      default: every platform in the stage
#
# <stage-dir> must carry the .verified marker fetch-verify.sh writes as its last action. Its
# SERIES must match the one given here, so this cannot be aimed at the wrong major version.
#
# Env: DRY_RUN=1      prepare and compare every platform, then stop without swapping
#      SERVE_ROOT     default /mnt/home/ccq/public_www. Overriding it marks the run sandboxed:
#                     BACKUP_ROOT then defaults alongside it and the HTTP post-flight is skipped.
#      BACKUP_ROOT    default /mnt/home/ccq/.triqs-deb-backups
#      REPO_GROUP     default ccq
#
# This is a bash script, not a snippet to paste: the shell these skills run under is zsh, where
# `set -e` does not reliably abort, and every guard below depends on it aborting.
set -Eeuo pipefail

[ $# -ge 2 ] || { echo "usage: $0 <series> <stage-dir> [platform ...]" >&2; exit 2; }
SERIES=$1; STAGE=$(realpath -m "$2"); shift 2
[[ $SERIES =~ ^[0-9]+\.[0-9]+\.x$ ]] || { echo "series must look like 4.0.x, got '$SERIES'" >&2; exit 2; }

LIVE_ROOT=$(realpath -m /mnt/home/ccq/public_www)
SERVE_ROOT="${SERVE_ROOT:-$LIVE_ROOT}"
# realpath on both sides, not a string compare: a trailing slash must not read as "sandboxed" and
# then publish to the live tree with the post-flight silently skipped, nor a symlinked /mnt/home
# make the unset default read that way.
if [ "$(realpath -m "$SERVE_ROOT")" = "$LIVE_ROOT" ]; then
  SANDBOXED=false; BACKUP_ROOT="${BACKUP_ROOT:-/mnt/home/ccq/.triqs-deb-backups}"
else
  SANDBOXED=true;  BACKUP_ROOT="${BACKUP_ROOT:-$SERVE_ROOT/../.triqs-deb-backups}"
  case "$(realpath -m "$BACKUP_ROOT")" in
    /mnt/home/ccq|/mnt/home/ccq/*)
      echo "sandboxed run must not use a BACKUP_ROOT under /mnt/home/ccq" >&2; exit 2 ;;
  esac
fi
SANDBOX_TAG=; [ "$SANDBOXED" = true ] && SANDBOX_TAG='   (SANDBOX)'
REPO_GROUP="${REPO_GROUP:-ccq}"

# .verified is data, not code — read the fields out rather than sourcing a file from the stage.
field() { sed -n "s/^$1=//p;T;q" "$STAGE/.verified"; }
[ -f "$STAGE/.verified" ] || { echo "$STAGE was not verified — run fetch-verify.sh first" >&2; exit 2; }
STAGE_SERIES=$(field SERIES); VERIFIED_BUILD=$(field VERIFIED_BUILD); PLATFORMS=$(field PLATFORMS)
for f in STAGE_SERIES VERIFIED_BUILD PLATFORMS; do
  [ -n "${!f}" ] || { echo "$STAGE/.verified records no ${f#STAGE_} — re-run fetch-verify.sh" >&2; exit 2; }
done
[ "$STAGE_SERIES" = "$SERIES" ] \
  || { echo "stage was verified for series $STAGE_SERIES, not $SERIES" >&2; exit 2; }

MAJOR=${SERIES%%.*}
SERVE="$SERVE_ROOT/triqs$MAJOR"
BACKUP="$BACKUP_ROOT/triqs$MAJOR"
# /mnt/home/ccq/public_www/triqs -> triqs2 is a legacy symlink; never publish through one.
[ ! -L "$SERVE" ] || { echo "$SERVE is a symlink — refusing to publish through it" >&2; exit 2; }

WANT=("$@"); [ ${#WANT[@]} -gt 0 ] || read -r -a WANT <<<"$PLATFORMS"
for p in "${WANT[@]}"; do
  # A codename becomes $SERVE/$p and an rm -rf glob below, and .verified is data off the stage.
  [[ $p =~ ^[a-z][a-z0-9-]*$ ]] || { echo "'$p' is not a plausible codename" >&2; exit 2; }
  case " $PLATFORMS " in *" $p "*) ;; *)
    echo "'$p' is not in the verified set ($PLATFORMS)" >&2; exit 2 ;;
  esac
  [ -d "$STAGE/$p" ] && grep -q "  $p.tgz\$" "$STAGE/.tarball-sums" \
    || { echo "'$p' has no verified tree or checksum in the stage" >&2; exit 2; }
done

# The stage sat on disk between verification and now; confirm the tarballs are still the ones
# that were checked before extracting any of them again.
( cd "$STAGE" && sha256sum -c --quiet .tarball-sums )
echo "stage: verified build #$VERIFIED_BUILD, tarballs unchanged"
echo "publishing [${WANT[*]}] into $SERVE${DRY_RUN:+   (DRY RUN)}$SANDBOX_TAG"

# One publisher at a time. The lock sits beside what it guards, so a sandboxed run does not
# contend with a real one — and two real runs always share it.
mkdir -p "$SERVE_ROOT"
exec 9>"$SERVE_ROOT/../.triqs-publish.lock"
flock -n 9 || { echo "another publish holds $SERVE_ROOT/../.triqs-publish.lock" >&2; exit 1; }

declare -a PREPARED=() PUBLISHED=() LIVE=()
declare -A ALREADY=()             # platforms whose live tree already matches the stage
SWAPPED_OUT=                      # set only while $DEST is vacant, between the two renames
finish() {
  local rc=$?
  # If we died with a codename moved out and nothing put back, restore it before anything else.
  if [ -n "$SWAPPED_OUT" ] && [ ! -e "$DEST" ]; then
    if mv -T "$SWAPPED_OUT" "$DEST"; then
      echo "RECOVERED: $DEST restored from $SWAPPED_OUT" >&2
    else
      echo "CRITICAL: $DEST is missing and could not be restored from $SWAPPED_OUT" >&2
    fi
  fi
  for d in "${PREPARED[@]}"; do [ -e "$d" ] && rm -rf "$d"; done   # unswapped prepared trees
  if [ ${#PUBLISHED[@]} -gt 0 ]; then
    echo
    echo "published this run: ${PUBLISHED[*]}"
    for p in "${PUBLISHED[@]}"; do
      # .bad goes to $BACKUP, not beside the live tree: under $SERVE it would be a second
      # publicly fetchable signed repo, which is why the backups live outside public_www at all.
      [ -e "$BACKUP/$p.prev" ] \
        && echo "  rollback $p:  mv -T $SERVE/$p $BACKUP/$p.bad && mv -T $BACKUP/$p.prev $SERVE/$p"
    done
    echo "  when satisfied:  rm -rf $BACKUP"
  fi
  [ $rc -eq 0 ] || echo "publish: FAILED (rc=$rc) — platforms listed above, if any, are already live" >&2
  return $rc
}
trap finish EXIT
# Without these bash runs the EXIT handler the instant a fatal signal lands, orphaning the mv that
# is still in flight; an explicit exit defers it to a command boundary and gives finish() a real $?.
trap 'exit 130' INT
trap 'exit 143' TERM

# ---- prepare every platform before swapping any ----------------------------
# A quota or permission failure on the last platform must not leave the matrix half updated.
mkdir -p "$SERVE"
for p in "${WANT[@]}"; do
  DEST="$SERVE/$p"; NEW="$DEST.new.$$"
  echo "== $p: prepare"
  [ ! -L "$DEST" ] || { echo "  $DEST is a symlink — refusing" >&2; exit 2; }

  # Both decisions belong here, not at swap time: a .prev conflict on the last platform must not
  # surface only once the first is already live.
  if [ -d "$DEST" ] && diff -rq "$STAGE/$p" "$DEST" >/dev/null 2>&1; then
    ALREADY[$p]=1
    echo "  live tree already matches the stage — will not re-swap"
  elif [ -e "$BACKUP/$p.prev" ] || [ -L "$BACKUP/$p.prev" ]; then
    echo "  FAIL: $BACKUP/$p.prev already exists" >&2
    if [ -d "$DEST" ]; then
      echo "        It is the rollback copy for the release currently live. Pick one, then re-run:" >&2
      echo "          keep the live release:  rm -rf $BACKUP/$p.prev" >&2
      echo "          roll back to it:        mv -T $SERVE/$p $BACKUP/$p.bad && mv -T $BACKUP/$p.prev $SERVE/$p" >&2
    else
      echo "        $DEST is missing, so an earlier run was interrupted mid-swap and .prev is the" >&2
      echo "        only copy of that codename. Put it back, then re-run:" >&2
      echo "          mv -T $BACKUP/$p.prev $SERVE/$p" >&2
    fi
    exit 1
  fi

  rm -rf "$SERVE/$p".new.*                          # leftovers from an earlier aborted run
  mkdir -p "$NEW"; PREPARED+=("$NEW")

  # Prepare alongside, never in place: InRelease sits near the front of the tarball, so an
  # in-place extract briefly serves a valid signed index pointing at debs that do not exist yet.
  tar xzf "$STAGE/$p.tgz" -C "$NEW" --no-same-owner --no-same-permissions --no-overwrite-dir
  # Group-readable, never group-writable: a signed index nobody but the publisher can overwrite
  # cannot be corrupted by an unrelated ccq member, and republishing goes through this script.
  chgrp -R "$REPO_GROUP" "$NEW" \
    || echo "  note: could not chgrp to $REPO_GROUP — $p will stay owned by $USER's group"
  chmod 755 "$NEW"
  find "$NEW" -type f -exec chmod 644 {} +

  diff -r --brief "$STAGE/$p" "$NEW"
  echo "  prepared: matches the verified stage"
done

if [ -n "${DRY_RUN:-}" ]; then
  echo "dry run complete — nothing was published"     # finish() removes the prepared trees
  exit 0
fi

# Past the rehearsal exit, so DRY_RUN cannot quietly re-own the live tree.
chgrp "$REPO_GROUP" "$SERVE" 2>/dev/null && chmod 755 "$SERVE" 2>/dev/null \
  || echo "note: could not set $REPO_GROUP ownership on $SERVE"

# Moving the old tree out is a rename(2) only within one filesystem; across two, mv degrades to a
# copy that deletes the live tree slowly while it is being served.
mkdir -p "$BACKUP"
[ "$(stat -c %d "$SERVE")" = "$(stat -c %d "$BACKUP")" ] \
  || { echo "$SERVE and $BACKUP are on different filesystems — refusing" >&2; exit 1; }

# ---- swap ------------------------------------------------------------------
for p in "${WANT[@]}"; do
  DEST="$SERVE/$p"; NEW="$DEST.new.$$"
  echo "== $p: swap"

  # Already-published is not a reason to re-swap, and re-swapping is how the backup gets eaten.
  if [ -n "${ALREADY[$p]:-}" ]; then
    echo "  already published and identical — skipped"
    LIVE+=("$p"); continue
  fi

  if [ -d "$DEST" ]; then
    # Set before the rename, not after: on a signal bash runs the EXIT handler at once, so a flag
    # set afterwards leaves the codename moved out with nothing recorded to restore it from.
    SWAPPED_OUT="$BACKUP/$p.prev"
    mv -T "$DEST" "$BACKUP/$p.prev"
    echo "  previous tree -> $BACKUP/$p.prev"
  fi
  mv -T "$NEW" "$DEST"; SWAPPED_OUT=
  PREPARED=("${PREPARED[@]/$NEW}")
  # Recorded before the diff below: if that fails the tree is live either way, and the operator
  # needs its rollback line more then, not less.
  PUBLISHED+=("$p"); LIVE+=("$p")

  diff -r --brief "$STAGE/$p" "$DEST"
  echo "  published: $DEST == verified stage"
done

# ---- post-flight over HTTP -------------------------------------------------
if [ "$SANDBOXED" = true ]; then
  echo
  echo "post-flight: SKIPPED — SERVE_ROOT is overridden, the live URL cannot reflect this run"
  exit 0
fi
[ -d "$STAGE/.gnupg" ] || { echo "post-flight: $STAGE/.gnupg is gone; cannot verify anything" >&2; exit 1; }

# Every platform whose live tree matches the stage, not only the ones swapped this run: after a
# post-flight failure the re-run skips them all as identical, and an empty loop must not read as
# a pass on exactly the path that re-run exists to re-check.
http_ok=1
for p in "${LIVE[@]}"; do
  url="https://users.flatironinstitute.org/~ccq/triqs$MAJOR/$p"
  echo "== $p post-flight: $url"
  plat_ok=1
  # Comparing bytes is strictly stronger than re-verifying the signature: it also catches a
  # cached or stale-but-validly-signed InRelease from a previous release.
  if wget --no-netrc -qO- -T 30 --tries=2 "$url/InRelease" | cmp -s - "$STAGE/$p/InRelease"; then
    echo "  InRelease over HTTP == the verified file"
  else
    echo "  InRelease over HTTP DIFFERS from the verified file"; plat_ok=0
  fi
  for d in $(awk '/^Filename:/{sub(/^\.\//,"",$2); print $2}' "$STAGE/$p/Packages"); do
    wget --no-netrc --spider -q -T 30 --tries=2 "$url/$d" && continue
    rc=$?
    case $rc in
      8) echo "  server error (404 or other 4xx/5xx): $d" ;;
      *) echo "  unreachable (wget rc=$rc, likely transient): $d" ;;
    esac
    plat_ok=0
  done
  [ $plat_ok -eq 1 ] && echo "  all $(grep -c '^Filename:' "$STAGE/$p/Packages") indexed debs fetchable"
  [ $plat_ok -eq 1 ] || http_ok=0
done

if [ $http_ok -eq 1 ]; then
  echo "post-flight: every published tree verifies over HTTP"
else
  echo "post-flight: HTTP checks FAILED. The swap succeeded and the live trees match the verified" >&2
  echo "             stage — investigate the web server, not the publish. Re-running is safe: it" >&2
  echo "             refuses rather than clobbering the rollback copy." >&2
  exit 1
fi
