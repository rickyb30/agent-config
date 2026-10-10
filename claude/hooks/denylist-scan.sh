#!/usr/bin/env bash
# Blocks employer names, internal domains, emails, usernames and home paths from
# entering a repository. Terms come from a machine-local file that is never committed,
# because a committed list would itself leak the terms.
#
#   denylist-scan.sh [--staged]     scan staged files (git pre-commit). Default.
#   denylist-scan.sh --tree [DIR]   scan tracked files in DIR (default .), used by validate.sh.
#   --allow-missing                 exit 0 with a notice when the denylist file is absent (CI).
#
# Denylist: $AGENT_CONFIG_DENYLIST or ~/.config/agent-config/denylist.txt
# One term per line, matched case-insensitively as a fixed string. # starts a comment.
set -u

mode=staged
dir=.
allow_missing=0
while [ $# -gt 0 ]; do
  case "$1" in
    --staged) mode=staged ;;
    --tree)
      mode=tree
      case "${2:-}" in
        "" | --*) ;;
        *)
          dir="$2"
          shift
          ;;
      esac
      ;;
    --allow-missing) allow_missing=1 ;;
    *)
      echo "usage: denylist-scan.sh [--staged | --tree DIR] [--allow-missing]" >&2
      exit 64
      ;;
  esac
  shift
done

list="${AGENT_CONFIG_DENYLIST:-$HOME/.config/agent-config/denylist.txt}"
if [ ! -f "$list" ]; then
  if [ "$allow_missing" -eq 1 ]; then
    echo "denylist-scan: no denylist at $list, skipped."
    exit 0
  fi
  echo "denylist-scan: no denylist at $list. Create it (scripts/bootstrap.sh writes a template) before committing." >&2
  exit 1
fi

patterns=$(mktemp "${TMPDIR:-/tmp}/denylist.XXXXXX") || exit 1
trap 'rm -f "$patterns"' EXIT
tr -d '\r' <"$list" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^#' | grep -v '^$' >"$patterns" || true
if [ ! -s "$patterns" ]; then
  echo "denylist-scan: $list has no terms yet, nothing checked." >&2
  exit 0
fi

cd "$dir" || exit 1
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "denylist-scan: $dir is not inside a git repository." >&2
  exit 1
}

hits=0
check_file() {
  # $1 = path as git prints it; file content arrives on stdin
  local f="$1" out
  if printf '%s\n' "$f" | grep -q -i -F -f "$patterns"; then
    echo "denylist-scan: file name matches a denylisted term: $f" >&2
    hits=$((hits + 1))
  fi
  out=$(grep -n -I -i -F -f "$patterns" 2>/dev/null | cut -c1-160)
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | sed "s|^|denylist-scan: $f:|" >&2
    hits=$((hits + 1))
  fi
}

if [ "$mode" = staged ]; then
  while IFS= read -r -d '' f; do
    check_file "$f" < <(git show ":$f" 2>/dev/null)
  done < <(git diff --cached --name-only -z --diff-filter=ACMR)
else
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    check_file "$f" <"$f"
  done < <(git ls-files -z --cached --others --exclude-standard)
fi

if [ "$hits" -gt 0 ]; then
  echo "denylist-scan: $hits file(s) contain denylisted terms. Remove or rewrite them; this repository must stay generic." >&2
  exit 1
fi
exit 0
