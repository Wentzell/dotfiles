#!/bin/bash
# Fetch and verify the TRIQS apt-repo tarballs archived by a packaging Jenkins build.
# Read-only: touches nothing outside <stage-dir>. Publishing is the caller's job.
#
#   fetch-verify.sh <series> <build> <stage-dir>
#
#   <series>     packaging release branch, X.Y.x
#   <build>      build number, or lastStableBuild.  lastSuccessfulBuild is rejected: Jenkins
#                counts UNSTABLE as successful and archiveArtifacts runs before the tests.
#   <stage-dir>  absent, or an existing empty directory you own
#
# Env: PACKAGING_DIR  default ~/Dropbox/Coding/packaging — supplies the trust-anchor public.gpg
#      ALLOW_UNSTABLE set to 1 to accept a build whose result is exactly UNSTABLE
#
# <stage-dir>/.build.env is working state written early; it proves nothing. The proof of
# verification is <stage-dir>/.verified, written atomically after every fallible step.
set -Eeuo pipefail
trap 'echo "fetch-verify: FAILED at line $LINENO" >&2' ERR

[ $# -eq 3 ] || { echo "usage: $0 <series> <build> <stage-dir>" >&2; exit 2; }
SERIES=$1 BUILD=$2
# Both go into URLs and filesystem paths; constrain them before either is built.
[[ $SERIES =~ ^[0-9]+\.[0-9]+\.x$ ]] || { echo "series must look like 4.0.x, got '$SERIES'" >&2; exit 2; }
if [ "$BUILD" = lastSuccessfulBuild ]; then
  echo "refusing lastSuccessfulBuild: Jenkins counts UNSTABLE as successful and the debs are" >&2
  echo "archived before the tests run. Use lastStableBuild, or pin the build number." >&2
  exit 2
fi
[[ $BUILD =~ ^([0-9]+|lastStableBuild)$ ]] || { echo "build must be a number or lastStableBuild, got '$BUILD'" >&2; exit 2; }

STAGE=$(realpath -m "$3")            # gpg and the per-platform subshells both cd; keep it absolute
PACKAGING_DIR="${PACKAGING_DIR:-$HOME/Dropbox/Coding/packaging}"
JOB="https://jenkins-new.flatironinstitute.org/job/CCQ/job/TRIQS/job/packaging/job/$SERIES"
WGET="wget --no-netrc -nv -T 60"     # -nv, not -q: a failed fetch must say so

if [ -e "$STAGE" ]; then
  [ -n "$(ls -A "$STAGE" 2>/dev/null)" ] \
    && { echo "stage dir $STAGE is not empty — stale debs from another build would be published" >&2; exit 2; }
  # A predictable path under a 1777 /tmp is pre-creatable by another user.
  [ -O "$STAGE" ] || { echo "stage dir $STAGE is not owned by $USER" >&2; exit 2; }
fi
[ -d "$PACKAGING_DIR/.git" ] || { echo "no packaging git repo at $PACKAGING_DIR (set PACKAGING_DIR)" >&2; exit 2; }

mkdir -p "$STAGE"; chmod 700 "$STAGE"
export GNUPGHOME="$STAGE/.gnupg"; mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"

check_sig() {                        # check_sig <label> <status-file> <gpg verify args...>
  local label=$1 st=$2; shift 2
  local reject='^\[GNUPG:\] (BADSIG|ERRSIG|EXPSIG|EXPKEYSIG|REVKEYSIG|NO_PUBKEY|KEYREVOKED|KEYEXPIRED)'
  local rc=0
  gpg --status-file "$st" --verify "$@" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  FAIL: $label — gpg exited $rc" >&2; return 1
  fi
  if grep -qE "$reject" "$st"; then
    echo "  FAIL: $label signature rejected:" >&2; grep -E "$reject" "$st" >&2; return 1
  fi
  # VALIDSIG's own field, not a substring match: gpg emits VALIDSIG alongside EXPKEYSIG, and a
  # subkey signature names the subkey in $3 and the primary in the last field.
  if ! awk -v fpr="$ANCHOR_FPR" \
        '$1=="[GNUPG:]" && $2=="VALIDSIG" && ($3==fpr || $NF==fpr){ok=1} END{exit !ok}' "$st"; then
    echo "  FAIL: $label is not signed by the anchor key $ANCHOR_FPR" >&2; return 1
  fi
  echo "  $label: good signature by $ANCHOR_FPR"
}

# ---- build identity --------------------------------------------------------
$WGET -O "$STAGE/.build.json" \
  "$JOB/$BUILD/api/json?tree=number,result,building,timestamp,artifacts[fileName],actions[lastBuiltRevision[SHA1]]"
python3 - "$STAGE/.build.json" > "$STAGE/.build.env" <<'PY'
import json, shlex, sys, time
b = json.load(open(sys.argv[1]))
plats = sorted(a["fileName"][:-4] for a in b.get("artifacts") or [] if a["fileName"].endswith(".tgz"))
sha = ""
for a in b.get("actions") or []:
    if isinstance(a, dict) and a.get("lastBuiltRevision"):
        sha = a["lastBuiltRevision"].get("SHA1", "") or ""
        break
ts = b.get("timestamp")
out = {
    "BUILD_NUMBER":   str(b.get("number", "")),
    "BUILD_RESULT":   str(b.get("result") or "RUNNING"),
    "BUILD_BUILDING": "true" if b.get("building") else "false",
    "BUILD_DATE":     time.strftime("%Y-%m-%dT%H:%M", time.localtime(ts / 1000)) if ts else "",
    "BUILD_SHA":      sha,
    "PLATFORMS":      " ".join(plats),
}
for k, v in out.items():
    print(f"{k}={shlex.quote(v)}")
PY
# shellcheck disable=SC1091
source "$STAGE/.build.env"

echo "build #$BUILD_NUMBER $BUILD_RESULT $BUILD_DATE  commit ${BUILD_SHA:0:12}  platforms: ${PLATFORMS:-(none)}"
# A running build archives per-platform inside `parallel`: half a matrix looks like a whole one.
[ "$BUILD_BUILDING" = false ] || { echo "build is still running — wait for it to finish" >&2; exit 1; }
[ -n "$PLATFORMS" ] || { echo "build archived no <platform>.tgz artifacts" >&2; exit 1; }
[[ $BUILD_NUMBER =~ ^[0-9]+$ ]] || { echo "no build number in the Jenkins response" >&2; exit 1; }
# Everything below fetches #$BUILD_NUMBER, never the alias again: lastStableBuild can advance
# between the metadata request and the downloads, pairing one build's debs with another's identity.
[[ $BUILD = lastStableBuild || $BUILD = "$BUILD_NUMBER" ]] \
  || { echo "asked for build $BUILD but Jenkins returned #$BUILD_NUMBER" >&2; exit 1; }
case "$BUILD_RESULT" in
  SUCCESS) ;;
  # UNSTABLE means a test suite failed; the debs were archived before the tests ran. FAILURE and
  # ABORTED are never publishable, override or not.
  UNSTABLE) [ "${ALLOW_UNSTABLE:-}" = 1 ] \
      || { echo "build is UNSTABLE — re-run with ALLOW_UNSTABLE=1 to publish it anyway" >&2; exit 1; }
    echo "WARNING: publishing an UNSTABLE build at the caller's request" ;;
  *) echo "build result is $BUILD_RESULT — not publishable" >&2; exit 1 ;;
esac
for p in $PLATFORMS; do
  [[ $p =~ ^[a-z][a-z0-9-]*$ ]] || { echo "artifact name '$p.tgz' is not a plausible codename" >&2; exit 1; }
done

# Everything below reads the commit Jenkins built, not the local branch tip, so it has to be
# present. Required rather than skippable: the cross-check goes blind exactly when a half-matrix
# would otherwise slip through.
# Must be a literal SHA1: git would equally accept HEAD or a tag, and the trust anchor and the
# provenance table would then come from a tree Jenkins never built.
[[ $BUILD_SHA =~ ^[0-9a-f]{40}$ ]] \
  || { echo "Jenkins reported no usable commit SHA1 (got '${BUILD_SHA:-}')" >&2; exit 1; }
if ! git -C "$PACKAGING_DIR" cat-file -e "$BUILD_SHA^{commit}" 2>/dev/null; then
  echo "build commit ${BUILD_SHA:-(unknown)} is not in $PACKAGING_DIR" >&2
  echo "  run: git -C $PACKAGING_DIR fetch origin $SERIES   then re-run" >&2
  exit 1
fi

# ---- trust anchor ----------------------------------------------------------
# Take the key from the commit itself, not from the worktree, so "the key committed to git" is
# literally what gets used even if the checkout is dirty.
ANCHOR="$STAGE/.anchor.gpg"
git -C "$PACKAGING_DIR" show "$BUILD_SHA:public.gpg" > "$ANCHOR"
cmp -s "$ANCHOR" "$PACKAGING_DIR/public.gpg" \
  || echo "NOTE: worktree public.gpg differs from ${BUILD_SHA:0:12}:public.gpg — using the committed key"
gpg -q --import "$ANCHOR"
mapfile -t FPRS < <(gpg --list-keys --with-colons | awk -F: '$1=="pub"{p=1;next} $1=="fpr"&&p{print $10;p=0}')
[ "${#FPRS[@]}" -eq 1 ] || { echo "expected exactly one key in public.gpg, found ${#FPRS[@]}" >&2; exit 1; }
ANCHOR_FPR=${FPRS[0]}
echo "trust anchor: ${BUILD_SHA:0:12}:public.gpg ($ANCHOR_FPR)"

# Cross-check against the matrix the pipeline declares: a platform whose stage timed out is
# absent from the artifacts and would otherwise be mistaken for a deliberately dropped codename.
JF=$(git -C "$PACKAGING_DIR" show "$BUILD_SHA:jenkins/Jenkinsfile" 2>/dev/null \
     || git -C "$PACKAGING_DIR" show "$BUILD_SHA:Jenkinsfile" 2>/dev/null || true)
DECLARED=$(printf '%s\n' "$JF" \
  | grep -oE 'def (packagePlatforms|platforms)[[:space:]]*=[[:space:]]*\[[^]]*\]' \
  | grep -oE '"[^"]+"' | tr -d '"' | sort -u | paste -sd' ' - || true)
if [ -z "$DECLARED" ]; then
  # Reformatting that list in the Jenkinsfile must not deadlock a release.
  [ "${ALLOW_MATRIX_SKIP:-}" = 1 ] || {
    echo "FAIL: no platform list found in ${BUILD_SHA:0:12}:{jenkins/,}Jenkinsfile" >&2
    echo "      confirm the matrix by hand, then re-run with ALLOW_MATRIX_SKIP=1" >&2; exit 1; }
  echo "WARNING: matrix cross-check skipped at the caller's request"
elif [ "$DECLARED" != "$PLATFORMS" ]; then
  echo "FAIL: Jenkinsfile declares [$DECLARED] but the build archived [$PLATFORMS]" >&2
  echo "      a stage probably failed or timed out; do not publish a partial matrix" >&2
  exit 1
else
  echo "matrix: [$DECLARED] as declared"
fi

# ---- per-platform verification --------------------------------------------
for p in $PLATFORMS; do
  echo "== $p"
  $WGET -O "$STAGE/$p.tgz" "$JOB/$BUILD_NUMBER/artifact/$p.tgz"

  # Inspect member types BEFORE extraction: tar silently rewrites an absolute path into a
  # relative one, and a hard link or device node never survives to be seen afterwards. Types come
  # from $1 and are reliable; names are not, so nothing here keys off them.
  tar -tvzf "$STAGE/$p.tgz" | awk '
    { type = substr($1,1,1)
      if (type == "d") { if ($NF != "./" && $NF != ".") { print "directory member: " $NF; bad=1 }; next }
      if (type != "-") { print "non-regular member (" type "): " $NF; bad=1 } }
    END { exit bad ? 1 : 0 }' \
    || { echo "  FAIL: $p.tgz has members that must not be published (above)" >&2; exit 1; }

  mkdir -p "$STAGE/$p" && tar xzf "$STAGE/$p.tgz" -C "$STAGE/$p" --no-same-owner

  # One member, one file. Catches duplicates without parsing names, which is what a name-based
  # check cannot do: ./x, /x and .//x are three spellings tar collapses onto one path, so the
  # second member overwrites a file the scan above already accepted.
  nmemb=$(tar -tzf "$STAGE/$p.tgz" | grep -vc '/$' || true)
  nfile=$(find "$STAGE/$p" -mindepth 1 | wc -l)
  [ "$nmemb" -eq "$nfile" ] \
    || { echo "  FAIL: $p.tgz lists $nmemb members but extracted $nfile files" >&2; exit 1; }

  # And again on what actually landed, against the flat set the pipeline produces.
  while IFS= read -r f; do
    { [ -f "$STAGE/$p/$f" ] && [ ! -L "$STAGE/$p/$f" ]; } \
      || { echo "  FAIL: $p.tgz member '$f' is not a regular file" >&2; exit 1; }
    case "$f" in
      */*) echo "  FAIL: $p.tgz member '$f' is in a subdirectory" >&2; exit 1 ;;
      InRelease|Release|Release.gpg|Packages|Packages.gz|Packages.bz2|public.gpg|*.deb) ;;
      *) echo "  FAIL: $p.tgz contains an unexpected member '$f'" >&2; exit 1 ;;
    esac
  done < <(cd "$STAGE/$p" && find . -mindepth 1 -printf '%P\n')

  cmp "$STAGE/$p/public.gpg" "$ANCHOR" \
    || { echo "  FAIL: bundled public.gpg differs from the committed key" >&2; exit 1; }

  check_sig InRelease "$STAGE/.status-$p-inrelease" "$STAGE/$p/InRelease"
  # InRelease's signature says nothing about the detached Release the checksums are read from.
  check_sig Release "$STAGE/.status-$p-release" "$STAGE/$p/Release.gpg" "$STAGE/$p/Release"

  (
    cd "$STAGE/$p"
    # apt consumes InRelease; every check below reads Release. They must be the same bytes.
    gpg -q -d InRelease 2>/dev/null | cmp -s - Release \
      || { echo "  FAIL: the InRelease payload differs from Release" >&2; exit 1; }
    echo "  InRelease payload == Release"

    awk '/^SHA256:/{f=1;next} /^[A-Za-z]/{f=0} f{print $1"  "$3}' Release | sha256sum -c --quiet
    # apt may fetch any of the three; nothing above proves they agree.
    gzip  -dc Packages.gz  | cmp -s - Packages || { echo "  FAIL: Packages.gz != Packages" >&2; exit 1; }
    bzip2 -dc Packages.bz2 | cmp -s - Packages || { echo "  FAIL: Packages.bz2 != Packages" >&2; exit 1; }
    echo "  Release: index checksums ok, all three indices agree"

    # Parse by stanza. Pairing Filename/SHA256 line-by-line silently skips a stanza that is
    # missing one of them while still counting it as verified.
    awk 'BEGIN { RS=""; FS="\n" }
      { pkg=""; fn=""; sha=""; nfn=0; nsha=0
        for (i=1; i<=NF; i++) {
          if      ($i ~ /^Package: /)  pkg = substr($i,10)
          else if ($i ~ /^Filename: /) { fn = substr($i,11); nfn++ }
          else if ($i ~ /^SHA256: /)   { sha = substr($i,9);  nsha++ } }
        if (pkg == "") next
        stanzas++
        if (nfn != 1 || nsha != 1) {
          printf "  stanza %s: %d Filename / %d SHA256, need exactly one each\n", pkg, nfn, nsha > "/dev/stderr"; bad=1; next }
        if (fn !~ /^\.\/[A-Za-z0-9._+~-]+$/) {
          printf "  stanza %s: unsafe Filename [%s]\n", pkg, fn > "/dev/stderr"; bad=1; next }
        if (sha !~ /^[0-9a-f]{64}$/) {
          printf "  stanza %s: malformed SHA256\n", pkg > "/dev/stderr"; bad=1; next }
        name = substr(fn, 3)
        if (name in seen) { printf "  duplicate Filename %s\n", name > "/dev/stderr"; bad=1; next }
        seen[name] = 1
        print sha "  " name }
      END { if (bad || stanzas == 0) exit 1 }' Packages > .debsums \
      || { echo "  FAIL: Packages is malformed (above)" >&2; exit 1; }

    sha256sum -c --quiet < .debsums
    # Both directions: an indexed deb that is absent, and a present deb that is unindexed.
    awk '{print $2}' .debsums | LC_ALL=C sort > .indexed
    find . -maxdepth 1 -name '*.deb' -printf '%P\n' | LC_ALL=C sort > .present
    diff .indexed .present \
      || { echo "  FAIL: indexed debs and files on disk disagree (< indexed, > on disk)" >&2; exit 1; }
    echo "  Packages: $(wc -l < .debsums) debs, checksums ok, index and disk agree"
    rm -f .debsums .indexed .present
  )

  # publish.sh extracts the tarball again; this lets it confirm it is the one verified here.
  ( cd "$STAGE" && sha256sum "$p.tgz" >> .tarball-sums )

  awk -v plat="$p" '/^Package: /{pkg=$2} /^Version: /{printf "  VERSION\t%s\t%s\t%s\n", plat, pkg, $2}' \
    "$STAGE/$p/Packages"
done

# ---- provenance ------------------------------------------------------------
# On a release branch every submodule pointer is a tagged revision, so each deb version must
# equal its module's tag at the commit Jenkins built. Both platforms build from one checkout,
# so one platform's index answers for all.
echo "== provenance: deb versions vs submodule tags at ${BUILD_SHA:0:12}"
first=${PLATFORMS%% *}
# The index lower-cases package names; submodule directories keep their case.
awk '/^Package: /{p=$2} /^Version: /{print p, $2}' "$STAGE/$first/Packages" \
  | LC_ALL=C sort > "$STAGE/.deb-versions"
git -C "$PACKAGING_DIR" ls-tree "$BUILD_SHA" | awk '$2=="commit"{print $4, $3}' \
  | while read -r m sha; do
      d="$PACKAGING_DIR/$m"
      if   [ ! -e "$d/.git" ];                                    then tag=NOT-CHECKED-OUT
      elif ! git -C "$d" cat-file -e "$sha^{commit}" 2>/dev/null;  then tag=NOT-FETCHED
      else tag=$(git -C "$d" describe --tags --exact-match "$sha" 2>/dev/null || echo UNTAGGED)
      fi
      echo "${m,,} ${tag#v}"        # every release tag here is bare X.Y.Z; legacy ones are vX.Y
    done | LC_ALL=C sort > "$STAGE/.module-tags"
# join must use the same collation the inputs were sorted in, or it mis-pairs the moment the
# two sides differ — which is the only case this check exists for.
LC_ALL=C join -a1 -a2 -e MISSING -o 0,1.2,2.2 "$STAGE/.deb-versions" "$STAGE/.module-tags" \
  | awk '{s = ($2==$3) ? "ok" : "MISMATCH"; if (s!="ok") bad++
          printf "  %-24s deb %-10s tag %-16s %s\n", $1, $2, $3, s}
         END {printf "  %d rows, %d not matching a tag\n", NR, bad+0}'

echo "staged: $(du -sh "$STAGE" | cut -f1) in $STAGE"

# Genuinely the last action, and atomic: publish.sh treats this file as the proof that
# everything above passed, so it must not exist after a partial run.
printf 'SERIES=%s\nVERIFIED_BUILD=%s\nPLATFORMS=%s\n' "$SERIES" "$BUILD_NUMBER" "$PLATFORMS" \
  > "$STAGE/.verified.tmp"
mv "$STAGE/.verified.tmp" "$STAGE/.verified"
echo "verified."
