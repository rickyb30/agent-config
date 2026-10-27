#!/usr/bin/env bash
# PreToolUse hook (Write, Edit, MultiEdit, NotebookEdit).
#
# In a project that opts in with .claude/pipeline.json this enforces the approval gate:
#   1. Source paths are writable only while docs/plans/.active names a plan whose
#      design (docs/architecture/...) has status: approved.
#   2. Approval is human-only: no tool call may leave a design doc with
#      status: approved, and .claude/pipeline.json itself cannot be edited.
#
# Projects without .claude/pipeline.json are not affected.
set -u

HOOK_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HOOK_DIR/lib/common.sh"

need_jq
input=$(cat)

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
case "$tool" in
  Write | Edit | MultiEdit | NotebookEdit) ;;
  *) exit 0 ;;
esac

path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] || exit 0

proj="${CLAUDE_PROJECT_DIR:-}"
[ -n "$proj" ] || proj=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$proj" ] || exit 0
proj="${proj%/}"

config="$proj/.claude/pipeline.json"

rel=$(rel_path "$proj" "$path")
case $? in
  0) ;;
  1) exit 0 ;; # outside the project: not this gate's business
  *)
    [ -f "$config" ] || exit 0
    hook_deny "Blocked: '$path' contains . or .. segments. Use a normalised path."
    ;;
esac

# Human-only even before it exists: it opts the project in and can allow deploy commands.
if [ "$rel" = .claude/pipeline.json ]; then
  hook_deny "Blocked: .claude/pipeline.json configures the approval gates and is edited by a human only."
fi
[ -f "$config" ] || exit 0

doc_status() { fm_get status | lower; }

# resulting_content: what the target file would contain after this tool call.
resulting_content() {
  if [ "$tool" = Write ]; then
    printf '%s' "$input" | jq -r '.tool_input.content // ""'
    return
  fi
  local current
  current=$(mktemp "${TMPDIR:-/tmp}/gate.XXXXXX") || return 1
  if [ -f "$proj/$rel" ]; then cat "$proj/$rel" >"$current"; fi
  printf '%s' "$input" | jq -r --rawfile cur "$current" '
    def rep($o; $n; $all):
      if $o == "" then . + $n
      else split($o) as $p
        | if ($p | length) < 2 then .
          elif $all then $p | join($n)
          else $p[0] + $n + ($p[1:] | join($o))
          end
      end;
    (.tool_input.edits // [.tool_input]) as $edits
    | reduce $edits[] as $e ($cur;
        rep($e.old_string // ""; $e.new_string // ""; ($e.replace_all // false)))'
  rm -f "$current"
}

case "$rel" in
  docs/architecture/*.md)
    if [ "$(resulting_content | doc_status)" = approved ]; then
      hook_deny "Blocked: '$rel' would have status: approved after this change. Approval is a human gate, and an approved design is read-only for agents. The human sets the status, or sets it back to draft before asking for edits."
    fi
    exit 0
    ;;
esac

# Is this path gated? Explicit source_paths wins; otherwise everything except docs/ and .claude/.
gated=0
if jq -e '(.source_paths // []) | length > 0' "$config" >/dev/null 2>&1; then
  while IFS= read -r prefix; do
    [ -n "$prefix" ] || continue
    prefix="${prefix#./}"
    prefix="${prefix%/}"
    case "$rel" in
      "$prefix" | "$prefix"/*) gated=1 ;;
    esac
  done <<EOF
$(jq -r '.source_paths[]' "$config" 2>/dev/null)
EOF
else
  case "$rel" in
    docs/* | .claude/*) gated=0 ;;
    *) gated=1 ;;
  esac
fi
[ "$gated" -eq 1 ] || exit 0

pointer="$proj/docs/plans/.active"
[ -f "$pointer" ] || hook_deny "Blocked: '$rel' is a source path and no plan is active. Approve the design, run /rb-intake on it, then /rb-implement <plan>."

plan=$(head -n 1 "$pointer" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
plan="${plan#./}"
case "$plan" in
  docs/plans/*.md) ;;
  *) hook_deny "Blocked: docs/plans/.active must name a file under docs/plans/ (found '$plan')." ;;
esac
case "$plan/" in
  */../*) hook_deny "Blocked: docs/plans/.active must not contain '..'." ;;
esac
[ -f "$proj/$plan" ] || hook_deny "Blocked: active plan '$plan' does not exist."

arch=$(fm_get design <"$proj/$plan")
[ -n "$arch" ] || arch=$(fm_get architecture <"$proj/$plan")
arch="${arch#./}"
case "$arch" in
  docs/architecture/*.md) ;;
  *) hook_deny "Blocked: plan '$plan' needs front matter 'design: docs/architecture/NNN-name.md' (found '${arch:-nothing}')." ;;
esac
case "$arch/" in
  */../*) hook_deny "Blocked: the plan's design reference must not contain '..'." ;;
esac
[ -f "$proj/$arch" ] || hook_deny "Blocked: design '$arch' referenced by '$plan' does not exist."

arch_status=$(doc_status <"$proj/$arch")
[ "$arch_status" = approved ] || hook_deny "Blocked: design '$arch' has status '${arch_status:-missing}', not approved. The human approves the design before code is written."

exit 0
