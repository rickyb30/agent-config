#!/usr/bin/env bash
# Tests for hooks and scripts. Pure bash, runs on 3.2 and 5. Uses only temp directories:
# nothing here touches the real ~/.claude or the real denylist.
# The suite checks the exit status of [ ... ] conditions on purpose.
# shellcheck disable=SC2319
set -u

TESTS_DIR=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$TESTS_DIR/.." && pwd -P)
HOOKS="$REPO/claude/hooks"
SH="${BASH:-bash}"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/agent-config-tests.XXXXXX")
TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
check() {
  # check DESCRIPTION EXPECTED_EXIT ACTUAL_EXIT
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf '  FAIL  %s (expected exit %s, got %s)\n' "$1" "$2" "$3"
  fi
}
check_true() {
  # check_true DESCRIPTION COMMAND...
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf '  FAIL  %s\n' "$desc"
  fi
}

# hook HOOK_SCRIPT PROJECT JSON [ARGS...] -> exit code of the hook
hook() {
  local script="$1" proj="$2" json="$3"
  shift 3
  printf '%s' "$json" | CLAUDE_PROJECT_DIR="$proj" "$SH" "$HOOKS/$script" "$@" >/dev/null 2>&1
  echo $?
}
write_json() { jq -n --arg p "$1" --arg c "$2" '{tool_name:"Write",tool_input:{file_path:$p,content:$c}}'; }
edit_json() { jq -n --arg p "$1" --arg o "$2" --arg n "$3" '{tool_name:"Edit",tool_input:{file_path:$p,old_string:$o,new_string:$n}}'; }
agent_write_json() { jq -n --arg a "$1" --arg p "$2" '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$p,content:"x"}}'; }
bash_json() { jq -n --arg a "$1" --arg c "$2" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}'; }

doc() { printf -- '---\nstatus: %s\n%s---\n\n# Doc\n' "$1" "${2:-}"; }

# ---------------------------------------------------------------- portable.sh
echo "portable.sh"
# shellcheck source=../scripts/lib/portable.sh
. "$REPO/scripts/lib/portable.sh"
mkdir -p "$TMP/p/real"
echo hello >"$TMP/p/real/file"
ln -s real "$TMP/p/link"
ln -s link/file "$TMP/p/hop"
[ "$(realpath_p "$TMP/p/hop")" = "$TMP/p/real/file" ]
check "realpath_p follows chained relative links" 0 $?
[ "$(realpath_p "$TMP/p/link")" = "$TMP/p/real" ]
check "realpath_p resolves a directory link" 0 $?
sed_inplace 's/hello/bye/' "$TMP/p/real/file"
[ "$(cat "$TMP/p/real/file")" = bye ]
check "sed_inplace edits the file" 0 $?

# ---------------------------------------------------------------- require-approved-plan
echo "require-approved-plan.sh"
P="$TMP/proj"
mkdir -p "$P/.claude" "$P/docs/architecture" "$P/docs/plans" "$P/src"
G=require-approved-plan.sh

check "project without pipeline.json is not gated" 0 "$(hook $G "$P" "$(write_json "$P/src/app.py" x)")"

echo '{}' >"$P/.claude/pipeline.json"
check "source write with no active plan is blocked" 2 "$(hook $G "$P" "$(write_json "$P/src/app.py" x)")"
check "docs write is not gated" 0 "$(hook $G "$P" "$(write_json "$P/docs/notes.md" x)")"
check "write outside the project is not gated" 0 "$(hook $G "$P" "$(write_json "$TMP/elsewhere.txt" x)")"
check "path with .. is blocked" 2 "$(hook $G "$P" "$(write_json "$P/docs/../src/app.py" x)")"
check "pipeline.json is human-only" 2 "$(hook $G "$P" "$(write_json "$P/.claude/pipeline.json" '{}')")"

doc draft >"$P/docs/architecture/001-widget.md"
doc draft 'architecture: docs/architecture/001-widget.md
' >"$P/docs/plans/001-widget.md"
echo "docs/plans/001-widget.md" >"$P/docs/plans/.active"
check "draft plan blocks source" 2 "$(hook $G "$P" "$(write_json "$P/src/app.py" x)")"

doc approved 'architecture: docs/architecture/001-widget.md
' >"$P/docs/plans/001-widget.md"
check "approved plan with draft architecture blocks source" 2 "$(hook $G "$P" "$(write_json "$P/src/app.py" x)")"

doc approved >"$P/docs/architecture/001-widget.md"
check "approved plan and architecture allow source" 0 "$(hook $G "$P" "$(write_json "$P/src/app.py" x)")"
check "edit to source allowed too" 0 "$(hook $G "$P" "$(edit_json "$P/src/app.py" a b)")"

doc approved >"$P/docs/plans/001-widget.md"
check "approved plan without architecture reference blocks source" 2 "$(hook $G "$P" "$(write_json "$P/src/app.py" x)")"

echo "../outside.md" >"$P/docs/plans/.active"
check "active pointer outside docs/plans is blocked" 2 "$(hook $G "$P" "$(write_json "$P/src/app.py" x)")"

# approval is human-only
doc draft >"$P/docs/plans/002-next.md"
check "agent may write a draft plan" 0 "$(hook $G "$P" "$(write_json "$P/docs/plans/002-next.md" "$(doc draft)")")"
check "agent may not write an approved plan" 2 "$(hook $G "$P" "$(write_json "$P/docs/plans/002-next.md" "$(doc approved)")")"
check "agent may not flip draft to approved by edit" 2 "$(hook $G "$P" "$(edit_json "$P/docs/plans/002-next.md" draft approved)")"
check "split edit that ends approved is blocked" 2 "$(hook $G "$P" "$(edit_json "$P/docs/plans/002-next.md" "raft
---" "raft
---" | jq '.tool_input.old_string="status: draft" | .tool_input.new_string="status:   Approved"')")"
check "agent may set an architecture to challenged" 0 "$(hook $G "$P" "$(edit_json "$P/docs/plans/002-next.md" draft challenged)")"
check "approved architecture is read-only for agents" 2 "$(hook $G "$P" "$(edit_json "$P/docs/architecture/001-widget.md" "# Doc" "# Changed")")"
check "agent may demote approved to draft" 0 "$(hook $G "$P" "$(edit_json "$P/docs/architecture/001-widget.md" approved draft)")"
check "the word approved in a body is fine" 0 "$(hook $G "$P" "$(edit_json "$P/docs/plans/002-next.md" "# Doc" "Follows the approved architecture.")")"

# explicit source_paths
echo '{"source_paths":["src","lib/"]}' >"$P/.claude/pipeline.json"
rm "$P/docs/plans/.active"
check "source_paths gates listed folders" 2 "$(hook $G "$P" "$(write_json "$P/lib/x.py" x)")"
check "source_paths leaves other folders alone" 0 "$(hook $G "$P" "$(write_json "$P/README.md" x)")"
check "source_paths does not match on prefix only" 0 "$(hook $G "$P" "$(write_json "$P/srcdocs/x" x)")"

# ---------------------------------------------------------------- guard-paths
echo "guard-paths.sh"
G=guard-paths.sh
R=architecture-researcher
check "main session is unrestricted" 0 "$(hook $G "$P" "$(write_json "$P/src/app.py" x)")"
check "researcher writes docs/research" 0 "$(hook $G "$P" "$(agent_write_json $R "$P/docs/research/001-assessment.md")")"
check "researcher cannot write source" 2 "$(hook $G "$P" "$(agent_write_json $R "$P/src/app.py")")"
check "researcher cannot write the architecture doc" 2 "$(hook $G "$P" "$(agent_write_json $R "$P/docs/architecture/001-widget.md")")"
check "researcher cannot write docs/plans" 2 "$(hook $G "$P" "$(agent_write_json $R "$P/docs/plans/001-widget.md")")"
check "researcher cannot write outside the project" 2 "$(hook $G "$P" "$(agent_write_json $R "$TMP/elsewhere.md")")"
check "researcher cannot escape with .." 2 "$(hook $G "$P" "$(agent_write_json $R "$P/docs/research/../../src/a")")"
check "researcher may propose knowledge" 0 "$(hook $G "$P" "$(agent_write_json $R "$P/docs/knowledge/inbox/x.md")")"
check "role given as argument works without agent_type" 2 "$(hook $G "$P" "$(write_json "$P/src/app.py" x)" $R)"
check "planner writes docs/plans" 0 "$(hook $G "$P" "$(agent_write_json engineering-planner "$P/docs/plans/001-widget.md")")"
check "planner writes docs/adr" 0 "$(hook $G "$P" "$(agent_write_json engineering-planner "$P/docs/adr/0001-store.md")")"
check "planner cannot write docs/reviews" 2 "$(hook $G "$P" "$(agent_write_json engineering-planner "$P/docs/reviews/001-review.md")")"
check "reviewer writes docs/reviews" 0 "$(hook $G "$P" "$(agent_write_json independent-reviewer "$P/docs/reviews/001-review.md")")"
check "reviewer cannot edit source" 2 "$(hook $G "$P" "$(agent_write_json independent-reviewer "$P/src/app.py")")"
check "implementer writes source" 0 "$(hook $G "$P" "$(agent_write_json implementer "$P/src/app.py")")"
check "implementer cannot write curated knowledge" 2 "$(hook $G "$P" "$(agent_write_json implementer "$P/docs/knowledge/patterns/x.md")")"
check "implementer cannot write the knowledge index" 2 "$(hook $G "$P" "$(agent_write_json implementer "$P/docs/knowledge/INDEX.md")")"
check "implementer may propose knowledge" 0 "$(hook $G "$P" "$(agent_write_json implementer "$P/docs/knowledge/inbox/x.md")")"
V=independent-reviewer
check "reviewer may run git diff" 0 "$(hook $G "$P" "$(bash_json $V "git diff main...HEAD -- src")")"
check "reviewer may run git log" 0 "$(hook $G "$P" "$(bash_json $V "git log --oneline -20")")"
check "reviewer cannot run other commands" 2 "$(hook $G "$P" "$(bash_json $V "rm -rf src")")"
check "reviewer cannot chain commands" 2 "$(hook $G "$P" "$(bash_json $V "git diff; rm -rf src")")"
check "reviewer cannot redirect" 2 "$(hook $G "$P" "$(bash_json $V "git diff > src/app.py")")"
check "reviewer cannot use git diff --output" 2 "$(hook $G "$P" "$(bash_json $V "git diff --output=src/app.py")")"
check "reviewer cannot run git commit" 2 "$(hook $G "$P" "$(bash_json $V "git commit -am x")")"
check "implementer bash is unrestricted" 0 "$(hook $G "$P" "$(bash_json implementer "npm test && npm run lint")")"

# ---------------------------------------------------------------- denylist-scan
echo "denylist-scan.sh"
D="$TMP/denyrepo"
mkdir -p "$D"
git -C "$D" init -q
git -C "$D" config user.email test@example.com
git -C "$D" config user.name test
deny() { (cd "$D" && AGENT_CONFIG_DENYLIST="$1" "$SH" "$HOOKS/denylist-scan.sh" "${@:2}" >/dev/null 2>&1); echo $?; }
FIX="$TESTS_DIR/fixtures/denylist.txt"

echo "a generic note" >"$D/clean.md"
git -C "$D" add clean.md
check "clean staged file passes" 0 "$(deny "$FIX")"
echo "see the INITECH runbook" >"$D/leak.md"
git -C "$D" add leak.md
check "denylisted term is blocked, case-insensitively" 1 "$(deny "$FIX")"
git -C "$D" rm -q --cached leak.md
rm "$D/leak.md"
echo "path /home/pgibbons/code" >"$D/path.md"
git -C "$D" add path.md
check "denylisted home path is blocked" 1 "$(deny "$FIX")"
git -C "$D" rm -q --cached path.md
rm "$D/path.md"
echo ok >"$D/initech-notes.md"
git -C "$D" add initech-notes.md
check "denylisted file name is blocked" 1 "$(deny "$FIX")"
git -C "$D" rm -q --cached initech-notes.md
rm "$D/initech-notes.md"
check "missing denylist fails closed" 1 "$(deny "$TMP/none.txt")"
check "missing denylist with --allow-missing passes" 0 "$(deny "$TMP/none.txt" --allow-missing)"
printf '# only comments\n\n' >"$TMP/empty-deny.txt"
check "empty denylist passes" 0 "$(deny "$TMP/empty-deny.txt")"
echo "unstaged Initech text" >"$D/untracked.md"
check "--tree scans untracked files too" 1 "$(deny "$FIX" --tree .)"
rm "$D/untracked.md"
check "--tree passes on a clean tree" 0 "$(deny "$FIX" --tree .)"

# the real pre-commit hook, with a stub gitleaks so the test does not need the binary
mkdir -p "$TMP/bin"
printf '#!/bin/sh\nexit 0\n' >"$TMP/bin/gitleaks"
chmod +x "$TMP/bin/gitleaks"
mkdir -p "$D/claude" "$D/.githooks"
cp -R "$HOOKS" "$D/claude/hooks"
cp "$REPO/.githooks/pre-commit" "$D/.githooks/pre-commit"
git -C "$D" config core.hooksPath .githooks
commit() { (cd "$D" && PATH="$TMP/bin:$PATH" AGENT_CONFIG_DENYLIST="$FIX" git commit -q -m "$1" >/dev/null 2>&1); echo $?; }
check "git commit of clean content succeeds" 0 "$(commit clean)"
echo "contact someone@intranet.initech.example" >"$D/contact.md"
git -C "$D" add contact.md
check "git commit containing a denylisted term is blocked" 1 "$(commit leak)"

# ---------------------------------------------------------------- secret-scan
echo "secret-scan.sh"
printf '#!/bin/sh\nexit 1\n' >"$TMP/bin/gitleaks-leaky"
mkdir -p "$TMP/leakybin" "$TMP/emptybin"
cp "$TMP/bin/gitleaks-leaky" "$TMP/leakybin/gitleaks"
chmod +x "$TMP/leakybin/gitleaks"
for tool in jq cat dirname tr; do ln -s "$(command -v $tool)" "$TMP/emptybin/$tool"; done
scan() { printf '%s' "$2" | PATH="$1:$PATH" "$SH" "$HOOKS/secret-scan.sh" >/dev/null 2>&1; echo $?; }
check "clean write passes" 0 "$(scan "$TMP/bin" "$(write_json "$P/src/a" "hello")")"
check "write flagged by gitleaks is blocked" 2 "$(scan "$TMP/leakybin" "$(write_json "$P/src/a" "token")")"
check "edit flagged by gitleaks is blocked" 2 "$(scan "$TMP/leakybin" "$(edit_json "$P/src/a" a "token")")"
check "git commit with flagged staged changes is blocked" 2 "$(scan "$TMP/leakybin" "$(jq -n --arg d "$D" '{tool_name:"Bash",cwd:$d,tool_input:{command:"git commit -m x"}}')")"
check "other bash commands are not scanned" 0 "$(scan "$TMP/leakybin" "$(jq -n '{tool_name:"Bash",tool_input:{command:"git status"}}')")"
check "missing gitleaks is a non-blocking error in hook mode" 1 "$(printf '%s' "$(write_json "$P/src/a" x)" | PATH="$TMP/emptybin" "$SH" "$HOOKS/secret-scan.sh" >/dev/null 2>&1; echo $?)"
check "missing gitleaks fails closed at pre-commit" 1 "$(cd "$D" && PATH="$TMP/emptybin" "$SH" "$HOOKS/secret-scan.sh" --pre-commit >/dev/null 2>&1; echo $?)"

# ---------------------------------------------------------------- settings merge
echo "merge-settings.jq"
echo '{"model":"opus","permissions":{"allow":["Bash(git status:*)","Bash(make:*)"]},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"true"}]}]}}' >"$TMP/local.json"
merged=$(jq -s -f "$REPO/scripts/lib/merge-settings.jq" "$REPO/claude/settings.base.json" "$TMP/local.json")
check_true "local scalar is kept" jq -e '.model == "opus"' <<<"$merged"
check_true "arrays are unioned without duplicates" jq -e '(.permissions.allow | map(select(. == "Bash(git status:*)")) | length) == 1 and (.permissions.allow | index("Bash(make:*)")) != null' <<<"$merged"
check_true "base hooks survive" jq -e '.hooks.PreToolUse | length >= 1' <<<"$merged"
check_true "local hooks are added" jq -e '.hooks.Stop | length == 1' <<<"$merged"

# ---------------------------------------------------------------- bootstrap
echo "bootstrap.sh"
B="$TMP/checkout"
mkdir -p "$B"
(cd "$REPO" && tar cf - --exclude .git .) | (cd "$B" && tar xf -)
H="$TMP/home"
mkdir -p "$H/.claude/skills/synced/kept" "$H/.claude/agents"
echo "my old instructions" >"$H/.claude/CLAUDE.md"
echo '{"model":"opus"}' >"$H/.claude/settings.json"
echo "old agent" >"$H/.claude/agents/implementer.md"
echo "mine" >"$H/.claude/agents/my-own-agent.md"
boot() { HOME="$H" CLAUDE_HOME="" AGENT_CONFIG_HOME="" env -u CLAUDE_HOME -u AGENT_CONFIG_HOME HOME="$H" "$SH" "$B/scripts/bootstrap.sh" "$@"; }
snapshot() { (cd "$H" && find . | sort && find . -type l -exec readlink {} \; | sort && find . -type f -exec cksum {} \; | sort); }

boot --dry-run >/dev/null 2>&1
check "dry run exits cleanly" 0 $?
[ "$(cat "$H/.claude/CLAUDE.md")" = "my old instructions" ] && [ ! -e "$H/.config" ]
check "dry run changes nothing" 0 $?

boot >"$TMP/boot1.log" 2>&1
check "first bootstrap succeeds" 0 $?
[ "$(readlink "$H/.claude/CLAUDE.md")" = "$B/claude/CLAUDE.md" ]
check "CLAUDE.md is linked" 0 $?
[ "$(readlink "$H/.claude/hooks/guard-paths.sh")" = "$B/claude/hooks/guard-paths.sh" ] && [ -L "$H/.claude/hooks/lib" ]
check "hooks are linked per entry" 0 $?
[ -d "$H/.claude/skills/synced/kept" ] && [ ! -L "$H/.claude/skills" ]
check "existing skills folder content is preserved" 0 $?
[ "$(cat "$H/.claude/agents/my-own-agent.md")" = mine ]
check "unrelated agent file is left alone" 0 $?
check_true "old CLAUDE.md was backed up" grep -rqx "my old instructions" "$H/.claude/backups/agent-config"
check_true "old same-named agent was backed up" grep -rqx "old agent" "$H/.claude/backups/agent-config"
check_true "existing settings seeded settings.local.json" jq -e '.model == "opus"' "$H/.config/agent-config/settings.local.json"
check_true "generated settings keep the local model" jq -e '.model == "opus"' "$H/.claude/settings.json"
check_true "generated settings wire the hooks" jq -e '.hooks.PreToolUse | length >= 1' "$H/.claude/settings.json"
[ -f "$H/.config/agent-config/denylist.txt" ]
check "denylist template created" 0 $?

before=$(snapshot)
boot >"$TMP/boot2.log" 2>&1
check "second bootstrap succeeds" 0 $?
[ "$before" = "$(snapshot)" ]
check "second bootstrap changes nothing" 0 $?
check_true "second bootstrap says so" grep -q "nothing changed" "$TMP/boot2.log"

HOME="$H" env -u CLAUDE_HOME -u AGENT_CONFIG_HOME HOME="$H" PATH="$TMP/bin:$PATH" "$SH" "$B/scripts/doctor.sh" >"$TMP/doctor.log" 2>&1
check_true "doctor finds every link intact" grep -q "link(s) intact" "$TMP/doctor.log"
check_true "doctor finds settings in sync" grep -q "settings.json matches" "$TMP/doctor.log"

rm "$B/claude/agents/implementer.md"
boot >/dev/null 2>&1
[ ! -L "$H/.claude/agents/implementer.md" ]
check "stale link is pruned when an entry is removed" 0 $?

# --ref pins a tag
T="$TMP/tagged"
mkdir -p "$T"
(cd "$REPO" && tar cf - --exclude .git .) | (cd "$T" && tar xf -)
git -C "$T" init -q
git -C "$T" config user.email test@example.com
git -C "$T" config user.name test
git -C "$T" add -A
git -C "$T" commit -q -m one --no-verify
git -C "$T" tag v9.9.9
echo extra >>"$T/VERSION"
git -C "$T" commit -q -am two --no-verify
H2="$TMP/home2"
mkdir -p "$H2"
env -u CLAUDE_HOME -u AGENT_CONFIG_HOME HOME="$H2" "$SH" "$T/scripts/bootstrap.sh" --ref v9.9.9 >/dev/null 2>&1
check "bootstrap --ref succeeds" 0 $?
[ "$(git -C "$T" describe --tags --exact-match 2>/dev/null)" = v9.9.9 ] && [ -L "$H2/.claude/CLAUDE.md" ]
check "checkout is detached at the tag and linked" 0 $?
env -u CLAUDE_HOME -u AGENT_CONFIG_HOME HOME="$H2" "$SH" "$T/scripts/bootstrap.sh" --ref v0.0.0 >/dev/null 2>&1
check "unknown tag is refused" 1 $?

echo
echo "tests: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
