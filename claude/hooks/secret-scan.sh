#!/usr/bin/env bash
# Secret scanning with gitleaks.
#
#   secret-scan.sh               PreToolUse hook: reads the tool call on stdin.
#                                Write/Edit -> scans the text about to be written.
#                                Bash running `git commit` -> scans staged changes.
#   secret-scan.sh --pre-commit  git pre-commit: scans staged changes, fails closed.
#   secret-scan.sh --tree [DIR]  scans files in DIR (default .), used by validate.sh.
set -u

HOOK_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HOOK_DIR/lib/common.sh"

have_gitleaks() { command -v gitleaks >/dev/null 2>&1; }

mode="${1:-hook}"

case "$mode" in
  --pre-commit)
    have_gitleaks || {
      echo "secret-scan: gitleaks is not installed, refusing to commit. Run scripts/doctor.sh." >&2
      exit 1
    }
    gitleaks_staged || {
      echo "secret-scan: possible secret in staged changes. Commit blocked." >&2
      exit 1
    }
    exit 0
    ;;
  --tree)
    have_gitleaks || {
      echo "secret-scan: gitleaks is not installed." >&2
      exit 1
    }
    gitleaks_tree "${2:-.}"
    exit $?
    ;;
  hook) ;;
  *)
    echo "usage: secret-scan.sh [--pre-commit | --tree DIR]" >&2
    exit 64
    ;;
esac

# PreToolUse mode. The git pre-commit hook is the hard gate, so a machine without
# gitleaks gets a visible non-blocking error here instead of a dead session.
need_jq
input=$(cat)
have_gitleaks || {
  echo "secret-scan: gitleaks is not installed, tool call not scanned. Run scripts/doctor.sh." >&2
  exit 1
}

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
case "$tool" in
  Write | Edit | MultiEdit | NotebookEdit)
    text=$(printf '%s' "$input" | jq -r '
      .tool_input
      | [.content, .new_string, .new_source, (.edits // [] | .[].new_string)]
      | map(select(. != null)) | join("\n")')
    [ -n "$text" ] || exit 0
    if ! printf '%s\n' "$text" | gitleaks_stdin >/dev/null 2>&1; then
      hook_deny "Blocked: the content being written looks like it contains a secret (gitleaks). Use an environment variable or a secret store reference instead."
    fi
    ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
    re='(^|[^[:alnum:]_-])git([[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'
    if [[ "$cmd" =~ $re ]]; then
      cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
      if [ -n "$cwd" ]; then cd "$cwd" 2>/dev/null || exit 0; fi
      if ! gitleaks_staged >/dev/null 2>&1; then
        hook_deny "Blocked: gitleaks found a possible secret in the staged changes. Unstage or remove it before committing."
      fi
    fi
    ;;
esac
exit 0
