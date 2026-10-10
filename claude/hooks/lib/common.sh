#!/usr/bin/env bash
# Shared helpers for hooks. bash 3.2 compatible. Depends only on bash, git, jq, gitleaks.

# A PreToolUse hook blocks by exiting 2; stderr is shown to the model as the reason.
hook_deny() {
  printf '%s\n' "$*" >&2
  exit 2
}

# Gates fail closed: without jq the hook input cannot be read at all.
need_jq() {
  command -v jq >/dev/null 2>&1 || hook_deny "agent-config hook: jq is required but not installed. Run scripts/doctor.sh."
}

lower() { tr '[:upper:]' '[:lower:]'; }

# fm_get KEY < file -> value of a top-level key in the leading YAML front matter.
# Prints nothing when the file has no front matter or the key is absent.
fm_get() {
  awk -v key="$1" '
    { sub(/\r$/, "") }
    NR == 1 { if ($0 != "---") exit; next }
    /^---[ \t]*$/ { exit }
    {
      if (match($0, "^" key "[ \t]*:")) {
        v = substr($0, RLENGTH + 1)
        sub(/[ \t]+#.*$/, "", v)
        gsub(/^[ \t]+|[ \t]+$/, "", v)
        gsub(/^["\047]|["\047]$/, "", v)
        print v
        exit
      }
    }'
}

# fm_keys < file -> top-level front matter keys, one per line. Exit 1 if there is no front matter.
fm_keys() {
  awk '
    { sub(/\r$/, "") }
    NR == 1 { if ($0 != "---") exit 1; next }
    /^---[ \t]*$/ { closed = 1; exit }
    /^[A-Za-z][A-Za-z0-9_-]*[ \t]*:/ { k = $0; sub(/[ \t]*:.*$/, "", k); print k }
    END { if (NR == 0 || !closed) exit 1 }'
}

# rel_path ROOT PATH -> PATH relative to ROOT.
# Returns 1 when PATH is outside ROOT, 2 when PATH contains . or .. segments.
rel_path() {
  local root="${1%/}" p="$2" phys
  case "$p" in
    /*) ;;
    *) p="$root/$p" ;;
  esac
  case "$p/" in
    */../* | */./*) return 2 ;;
  esac
  case "$p" in
    "$root"/*)
      printf '%s\n' "${p#"$root"/}"
      return 0
      ;;
  esac
  phys=$(cd "$root" 2>/dev/null && pwd -P) || return 1
  case "$p" in
    "$phys"/*)
      printf '%s\n' "${p#"$phys"/}"
      return 0
      ;;
  esac
  return 1
}

# gitleaks changed its subcommands in 8.19 (git/dir/stdin replaced protect/detect).
gitleaks_modern() { gitleaks stdin --help >/dev/null 2>&1; }

# gitleaks_staged: scan staged changes of the repo in the current directory.
gitleaks_staged() {
  if gitleaks_modern; then
    gitleaks git --pre-commit --staged --redact --no-banner
  else
    gitleaks protect --staged --redact --no-banner
  fi
}

# gitleaks_stdin: scan text on stdin.
gitleaks_stdin() {
  if gitleaks_modern; then
    gitleaks stdin --redact --no-banner
  else
    gitleaks detect --pipe --redact --no-banner
  fi
}

# gitleaks_tree DIR: scan files in DIR, ignoring git history.
gitleaks_tree() {
  if gitleaks_modern; then
    gitleaks dir "$1" --redact --no-banner
  else
    gitleaks detect --no-git --source "$1" --redact --no-banner
  fi
}
