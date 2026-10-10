#!/usr/bin/env bash
# PreToolUse hook (Write, Edit, MultiEdit, NotebookEdit, Bash).
#
# Keeps each pipeline agent inside its own output folders:
#   architecture-researcher -> docs/research/
#   engineering-planner     -> docs/plans/, docs/adr/
#   independent-reviewer    -> docs/reviews/
# Every subagent may also write proposals to docs/knowledge/inbox/, and no subagent
# may write anywhere else under docs/knowledge/ (curation is a human step).
#
# The role comes from the first argument (agent front matter passes it explicitly)
# or from the agent_type field of the hook input (settings-level wiring).
# The main session has neither and is not restricted here.
set -u

HOOK_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HOOK_DIR/lib/common.sh"

need_jq
input=$(cat)

role="${1:-}"
[ -n "$role" ] || role=$(printf '%s' "$input" | jq -r '.agent_type // empty')
[ -n "$role" ] || exit 0

restricted=1
case "$role" in
  architecture-researcher) allowed="docs/research/ docs/knowledge/inbox/" ;;
  engineering-planner) allowed="docs/plans/ docs/adr/ docs/knowledge/inbox/" ;;
  independent-reviewer) allowed="docs/reviews/ docs/knowledge/inbox/" ;;
  *)
    restricted=0
    allowed=""
    ;;
esac

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')

if [ "$tool" = Bash ]; then
  [ "$restricted" -eq 1 ] || exit 0
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
  case "$cmd" in
    *[\;\&\|\>\<\`\$\(\)]* | *'
'*)
      hook_deny "Blocked: $role may only run a single read-only git command (no pipes, redirects or substitutions)."
      ;;
  esac
  case " $cmd " in
    *" --output"* | *" --ext-diff"* | *" --textconv"* | *" -c "* | *" --exec"* | *" -o "*)
      hook_deny "Blocked: $role may not pass that option to git."
      ;;
  esac
  ro='^git (diff|log|show|status|rev-parse|merge-base|ls-files|blame)( |$)'
  if [[ "$cmd" =~ $ro ]]; then exit 0; fi
  hook_deny "Blocked: $role is read-only. Allowed commands: git diff, log, show, status, rev-parse, merge-base, ls-files, blame."
fi

case "$tool" in
  Write | Edit | MultiEdit | NotebookEdit) ;;
  *) exit 0 ;;
esac

path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] || exit 0

proj="${CLAUDE_PROJECT_DIR:-}"
[ -n "$proj" ] || proj=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$proj" ] || hook_deny "Blocked: cannot determine the project directory for $role."
proj="${proj%/}"

rel=$(rel_path "$proj" "$path")
case $? in
  0) ;;
  1)
    [ "$restricted" -eq 1 ] || exit 0
    hook_deny "Blocked: $role may only write inside the project ($allowed)."
    ;;
  *) hook_deny "Blocked: '$path' contains . or .. segments. Use a normalised path." ;;
esac

case "$rel" in
  docs/knowledge/inbox/*) exit 0 ;;
  docs/knowledge/*)
    hook_deny "Blocked: agents write knowledge proposals to docs/knowledge/inbox/ only. Curated folders and INDEX.md are edited by a human."
    ;;
esac

[ "$restricted" -eq 1 ] || exit 0

for prefix in $allowed; do
  case "$rel" in
    "$prefix"*) exit 0 ;;
  esac
done

hook_deny "Blocked: $role may write only under: $allowed (attempted '$rel'). If the task seems to need more, stop and report instead."
