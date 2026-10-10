#!/usr/bin/env bash
# Lint this repository. Used locally and in CI.
#
#   scripts/validate.sh            run every check the machine has tools for
#   scripts/validate.sh --strict   missing shellcheck or gitleaks is a failure (CI)
#   scripts/validate.sh --no-tests skip tests/run.sh
set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=../claude/hooks/lib/common.sh
. "$REPO/claude/hooks/lib/common.sh"
cd "$REPO" || exit 1

strict=0
run_tests=1
for arg in "$@"; do
  case "$arg" in
    --strict) strict=1 ;;
    --no-tests) run_tests=0 ;;
    *)
      echo "usage: validate.sh [--strict] [--no-tests]" >&2
      exit 64
      ;;
  esac
done

errors=0
err() {
  printf '  FAIL  %s\n' "$*"
  errors=$((errors + 1))
}
section() { printf '%s\n' "$*"; }

AGENT_FIELDS="name description tools disallowedTools model permissionMode maxTurns skills mcpServers hooks memory background omitClaudeMd effort isolation color initialPrompt experimental"
SKILL_FIELDS="name description when_to_use argument-hint arguments disable-model-invocation user-invocable allowed-tools disallowed-tools model effort context agent background hooks paths shell metadata license compatibility"
COMMAND_FIELDS="description when_to_use argument-hint arguments disable-model-invocation user-invocable allowed-tools disallowed-tools model effort context agent background hooks shell"
HOOK_EVENTS="SessionStart Setup UserPromptSubmit UserPromptExpansion PreToolUse PermissionRequest PermissionDenied PostToolUse PostToolUseFailure PostToolBatch Notification SubagentStart SubagentStop Stop StopFailure PreCompact PostCompact SessionEnd"
MODELS="sonnet opus haiku fable inherit"
NONPORTABLE='(declare|local|typeset) +-A|readarray|mapfile|readlink +-f|sed +-i|date +-d' # validate-ignore

in_list() {
  local needle="$1" list="$2" item
  for item in $list; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

# check_fields FILE "ALLOWED FIELDS": unknown front matter keys fail loudly, because
# Claude Code ignores them silently and a typo would otherwise disable a setting.
check_fields() {
  local file="$1" allowed="$2" keys key
  if ! keys=$(fm_keys <"$file"); then
    err "$file: missing or unterminated front matter"
    return 1
  fi
  for key in $keys; do
    in_list "$key" "$allowed" || err "$file: unknown front matter field '$key'"
  done
}

section "agents"
for f in claude/agents/*.md; do
  [ -e "$f" ] || continue
  check_fields "$f" "$AGENT_FIELDS" || continue
  name=$(fm_get name <"$f")
  [ "$name" = "$(basename "$f" .md)" ] || err "$f: name '$name' must match the file name"
  [ -n "$(fm_get description <"$f")" ] || err "$f: description is required"
  [ -n "$(fm_get tools <"$f")" ] || err "$f: tools is required (agents here never inherit every tool)"
  case ",$(fm_get tools <"$f" | tr -d ' ')," in
    *,Agent,* | *,Task,*) err "$f: agents must not be able to spawn agents" ;;
  esac
  model=$(fm_get model <"$f")
  if [ -n "$model" ]; then
    case "$model" in
      claude-*) ;;
      *) in_list "$model" "$MODELS" || err "$f: unknown model '$model'" ;;
    esac
  fi
  [ "$(wc -l <"$f")" -le 120 ] || err "$f: over 120 lines. Agents are thin; move detail into a skill"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -f "claude/skills/$skill/SKILL.md" ] || err "$f: lists skill '$skill', which does not exist"
  done <<EOF
$(awk '/^skills:/{s=1;next} s&&/^[ \t]+-[ \t]*/{sub(/^[ \t]+-[ \t]*/,"");print;next} s&&/^[^ \t]/{s=0}' "$f")
EOF
done

section "skills"
for d in claude/skills/*/; do
  [ -d "$d" ] || continue
  f="${d}SKILL.md"
  if [ ! -f "$f" ]; then
    err "$d: SKILL.md is missing"
    continue
  fi
  check_fields "$f" "$SKILL_FIELDS" || continue
  name=$(fm_get name <"$f")
  [ "$name" = "$(basename "$d")" ] || err "$f: name '$name' must match the directory name"
  desc=$(fm_get description <"$f")
  [ -n "$desc" ] || err "$f: description is required"
  [ "${#desc}" -le 1024 ] || err "$f: description is over 1024 characters"
  [ "$(wc -l <"$f")" -le 500 ] || err "$f: over 500 lines. Move reference material into a supporting file"
done

section "commands"
for f in claude/commands/*.md; do
  [ -e "$f" ] || continue
  check_fields "$f" "$COMMAND_FIELDS" || continue
  [ -n "$(fm_get description <"$f")" ] || err "$f: description is required"
done

section "global CLAUDE.md"
[ "$(wc -l <claude/CLAUDE.md)" -le 200 ] || err "claude/CLAUDE.md: over 200 lines. Move detail into a skill"

section "settings.base.json"
if ! jq -e 'type == "object"' claude/settings.base.json >/dev/null 2>&1; then
  err "claude/settings.base.json: not a JSON object"
else
  for event in $(jq -r '.hooks // {} | keys[]' claude/settings.base.json); do
    in_list "$event" "$HOOK_EVENTS" || err "claude/settings.base.json: unknown hook event '$event'"
  done
  for script in $(jq -r '.. | objects | select(.type == "command") | .command' claude/settings.base.json |
    grep -o 'hooks/[A-Za-z0-9_.-]*\.sh' | sort -u); do
    [ -x "claude/$script" ] || err "claude/settings.base.json: claude/$script is missing or not executable"
  done
  jq -e '[.. | objects | select(has("type") and has("command")) | .type] | all(. == "command")' \
    claude/settings.base.json >/dev/null || err "claude/settings.base.json: only command hooks are expected"
fi

section "shell"
shell_files=$( (
  find claude/hooks scripts tests -name '*.sh' -type f
  find .githooks -type f
) | sort)
for f in $shell_files; do
  "${BASH:-bash}" -n "$f" 2>/dev/null || err "$f: syntax error"
  if grep -q "$(printf '\r')" "$f"; then err "$f: has CRLF line endings"; fi
  case "$f" in
    */lib/*) ;;
    *) [ -x "$f" ] || err "$f: not executable" ;;
  esac
  if grep -n -E "$NONPORTABLE" "$f" |
    grep -v -E '^[0-9]+:[[:space:]]*#' | grep -v 'validate-ignore' >/dev/null; then
    err "$f: uses a construct that breaks on bash 3.2 or BSD tools (see docs/SETUP.md)"
  fi
done
if command -v shellcheck >/dev/null 2>&1; then
  # shellcheck disable=SC2086
  shellcheck -x -S warning $shell_files || err "shellcheck reported problems"
elif [ "$strict" -eq 1 ]; then
  err "shellcheck is not installed (required with --strict)"
else
  echo "  skip  shellcheck not installed"
fi

section "secrets and denylist"
if command -v gitleaks >/dev/null 2>&1; then
  claude/hooks/secret-scan.sh --tree . >/dev/null 2>&1 || err "gitleaks found a possible secret in the working tree"
elif [ "$strict" -eq 1 ]; then
  err "gitleaks is not installed (required with --strict)"
else
  echo "  skip  gitleaks not installed"
fi
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  claude/hooks/denylist-scan.sh --tree . --allow-missing || err "denylisted terms found in the working tree"
else
  echo "  skip  not a git checkout, denylist scan needs one"
fi

if [ "$run_tests" -eq 1 ]; then
  section "tests"
  "${BASH:-bash}" tests/run.sh || err "tests failed"
fi

echo
if [ "$errors" -gt 0 ]; then
  echo "validate: $errors problem(s)."
  exit 1
fi
echo "validate: ok."
