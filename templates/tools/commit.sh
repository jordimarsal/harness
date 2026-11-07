#!/usr/bin/env bash
# commit.sh — commit ONLY the paths you name.
#
# The harness dispatches several implementer sessions against one working
# tree (feature_list.json "parallel": true), so `git add .` would sweep up
# whatever another session has in flight. This tool stages exactly the paths
# given and commits exactly those; every other staged entry stays staged.
#
#   harness/tools/commit.sh -m "<subject>" [-m "<body>"]… [--] <path>…
#
# Exit 2 — refused: no -m, no paths, -a/-A/--all/--amend/-i/--patch, an
#   unknown flag, or a path that is ".", "", "*", holds "..", or leaves the
#   repository.
# Exit 1 — git itself failed: the commit-msg hook rejected a non-conventional
#   subject, the paths had no changes, or a merge is in progress (git cannot
#   make a partial commit then — finish the merge and retry).
# Retries while another session holds index.lock.
set -euo pipefail

die() { printf 'commit.sh: %s\n' "$*" >&2; exit 2; }

usage() {
  cat >&2 <<'EOF'
usage: harness/tools/commit.sh -m "<subject>" [-m "<body>"]… [--] <path>…

Commits exactly the paths named — never -a, never '.' — so sessions
sharing this tree cannot pick up each other's work. The subject must
satisfy Conventional Commits (.git/hooks/commit-msg enforces it).
EOF
}

# A parallel session may hold index.lock; wait it out rather than fail.
retry() {
  local out="" i=0
  while [ "$i" -lt 10 ]; do
    i=$((i + 1))
    if out=$("$@" 2>&1); then
      if [ -n "$out" ]; then printf '%s\n' "$out"; fi
      return 0
    fi
    case "$out" in
      *index.lock*)
        printf 'commit.sh: index.lock held, retry %d\n' "$i" >&2
        sleep 1
        ;;
      *)
        printf '%s\n' "$out" >&2
        return 1
        ;;
    esac
  done
  printf '%s\n' "$out" >&2
  return 1
}

msgs=()
paths=()
nmsg=0
npath=0
while [ $# -gt 0 ]; do
  case "$1" in
    -m)
      [ $# -ge 2 ] || die "-m needs a message"
      msgs+=("$2")
      nmsg=$((nmsg + 1))
      shift 2
      ;;
    -m*)
      msgs+=("${1#-m}")
      nmsg=$((nmsg + 1))
      shift
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do
        paths+=("$1")
        npath=$((npath + 1))
        shift
      done
      break
      ;;
    -a|-A|--all|--amend|-i|--interactive|-p|--patch)
      die "refusing $1 — name the paths you want committed"
      ;;
    -*)
      die "unknown flag $1"
      ;;
    *)
      paths+=("$1")
      npath=$((npath + 1))
      shift
      ;;
  esac
done

if [ "$nmsg" -eq 0 ]; then
  printf 'commit.sh: a message is required (-m)\n\n' >&2
  usage
  exit 2
fi
if [ "$npath" -eq 0 ]; then
  printf 'commit.sh: no paths given — refusing to commit without explicit paths\n\n' >&2
  usage
  exit 2
fi

top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"
prefix=$(git rev-parse --show-prefix)

# Normalise each path to a repo-relative form and screen it: absolute paths
# inside the repo lose the root, paths given from a subdirectory gain that
# subdirectory, "./" prefixes go. Guards run on the normalised form so no
# spelling of "." or ".." slips through; `git add` and `git commit` below keep
# the original argument, which git resolves against the current directory.
addpaths=()
nadd=0
for p in "${paths[@]}"; do
  rel="$p"
  case "$rel" in
    "$top")
      die "$p is the repository root — name the files"
      ;;
    "$top"/*)
      rel="${rel#"$top"/}"
      ;;
    /*)
      die "$p is outside the repository"
      ;;
    *)
      rel="$prefix$rel"
      ;;
  esac
  while [ "${rel#./}" != "$rel" ]; do rel="${rel#./}"; done
  rel="${rel%/}"
  case "/$rel/" in
    */../*) die "$p: use a path without '..'" ;;
  esac
  case "$rel" in
    ""|"."|"*") die "$p is the whole tree — name the files" ;;
  esac
  # A path that is neither in the worktree nor in the index was already
  # removed (git rm) by another session: skip `git add`, which would refuse
  # it, and let `git commit -- <path>` record the deletion. A typo lands here
  # too and fails at the commit with git's own message.
  if [ -e "$p" ] ||
     [ -n "$(git -C "$top" --literal-pathspecs ls-files -- "$rel" 2>/dev/null)" ]; then
    addpaths+=("$p")
    nadd=$((nadd + 1))
  fi
done

printf '== git status --short (before)\n'
git status --short

if [ "$nadd" -gt 0 ]; then
  # --literal-pathspecs: a path like ':/' or '*.go' is pathspec magic to git
  # and would walk straight past the guards above.
  retry git --literal-pathspecs add -- "${addpaths[@]}" || exit 1
fi

args=()
for m in "${msgs[@]}"; do args+=(-m "$m"); done
# A partial commit takes the named paths only: whatever another session had
# staged stays staged, untouched and uncommitted.
retry git --literal-pathspecs commit "${args[@]}" -- "${paths[@]}" || exit 1

printf '== committed %s\n' "$(git rev-parse --short HEAD)"
printf '== git status --short (after)\n'
git status --short
