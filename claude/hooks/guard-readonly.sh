#!/usr/bin/env bash
# PreToolUse hook for read-only agents, wired in the agent's front matter.
# Blocks file-writing tools, and any shell command other than one read-only git command.
set -u

HOOK_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HOOK_DIR/lib/common.sh"

need_jq
input=$(cat)

case "$(printf '%s' "$input" | jq -r '.tool_name // empty')" in
  Write | Edit | MultiEdit | NotebookEdit)
    hook_deny "Blocked: this agent is read-only. Report the finding instead of changing files."
    ;;
  Bash) ;;
  *) exit 0 ;;
esac

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
case "$cmd" in
  *[\;\&\|\>\<\`\$\(\)]* | *'
'*)
    hook_deny "Blocked: read-only agents may run a single git command only (no pipes, redirects or substitutions)."
    ;;
esac
case " $cmd " in
  *" --output"* | *" --ext-diff"* | *" --textconv"* | *" -c "* | *" --exec"* | *" -o "*)
    hook_deny "Blocked: read-only agents may not pass that option to git."
    ;;
esac
ro='^git (diff|log|show|status|rev-parse|merge-base|ls-files|blame)( |$)'
if [[ "$cmd" =~ $ro ]]; then exit 0; fi
hook_deny "Blocked: read-only agent. Allowed commands: git diff, log, show, status, rev-parse, merge-base, ls-files, blame."
