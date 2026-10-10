#!/usr/bin/env bash
# Check that this machine matches the repository. Read-only.
# Exit 0 when everything required is in place, 1 otherwise.
set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"
REPO=$(cd "$SCRIPT_DIR/.." && pwd -P)
SRC="$REPO/claude"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CONF="${AGENT_CONFIG_HOME:-$HOME/.config/agent-config}"

fails=0
warns=0
ok() { printf '  ok    %s\n' "$*"; }
bad() {
  printf '  FAIL  %s\n' "$*"
  fails=$((fails + 1))
}
meh() {
  printf '  warn  %s\n' "$*"
  warns=$((warns + 1))
}

echo "machine: $(os_kind), bash ${BASH_VERSION}"

echo "tools:"
for tool in bash git jq gitleaks python3; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool ($(command -v "$tool"))"
  else
    bad "$tool missing. Install: $(install_hint "$tool")"
  fi
done
if command -v shellcheck >/dev/null 2>&1; then
  ok "shellcheck"
else
  meh "shellcheck missing (only needed to run validate.sh --strict). Install: $(install_hint shellcheck)"
fi
if command -v claude >/dev/null 2>&1; then
  cv=$(claude --version 2>/dev/null | awk '{print $1; exit}')
  major=${cv%%.*}
  rest=${cv#*.}
  minor=${rest%%.*}
  case "$major$minor" in
    *[!0-9]* | "") meh "claude found, version not recognised ('$cv')" ;;
    *)
      if [ "$major" -gt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -ge 1 ]; }; then
        ok "claude $cv"
      else
        meh "claude $cv is old. The path guard relies on agent front matter hooks and the agent_type hook field; update Claude Code."
      fi
      ;;
  esac
else
  meh "claude CLI not on PATH"
fi

echo "checkout: $REPO"
if is_wsl; then
  case "$REPO" in
    /mnt/*) bad "checkout is on the Windows filesystem. Clone it inside the Linux filesystem." ;;
    *) ok "on the Linux filesystem" ;;
  esac
fi
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  tag=$(git -C "$REPO" describe --tags --exact-match 2>/dev/null || true)
  sha=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo "no commits")
  branch=$(git -C "$REPO" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  if [ -n "$tag" ]; then
    ok "pinned to tag $tag ($sha)"
  elif is_wsl; then
    meh "not on a tag (${branch:-detached} @ $sha). An office machine should be pinned: scripts/bootstrap.sh --ref vX.Y.Z"
  else
    ok "tracking ${branch:-detached} @ $sha (VERSION $(cat "$REPO/VERSION" 2>/dev/null))"
  fi
  [ -z "$(git -C "$REPO" status --porcelain 2>/dev/null)" ] || meh "checkout has uncommitted changes"
  if [ "$(git -C "$REPO" config --local --get core.hooksPath || true)" = ".githooks" ]; then
    ok "git pre-commit scans enabled"
  else
    bad "git pre-commit scans not enabled. Run scripts/bootstrap.sh"
  fi
else
  meh "not a git checkout"
fi

echo "links in $CLAUDE_HOME:"
check_link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return 0
  fi
  bad "${dst#"$CLAUDE_HOME"/} is not linked to this checkout. Run scripts/bootstrap.sh"
  return 1
}
linked=0
check_link "$SRC/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md" && linked=$((linked + 1))
for d in agents skills commands hooks; do
  for entry in "$SRC/$d"/*; do
    [ -e "$entry" ] || continue
    check_link "$entry" "$CLAUDE_HOME/$d/$(basename "$entry")" && linked=$((linked + 1))
  done
done
[ "$linked" -gt 0 ] && ok "$linked link(s) intact"
for hook in "$SRC"/hooks/*.sh; do
  [ -x "$hook" ] || bad "$(basename "$hook") is not executable"
done

echo "settings:"
local_settings="$CONF/settings.local.json"
if [ ! -f "$local_settings" ]; then
  bad "$local_settings missing. Run scripts/bootstrap.sh"
elif ! command -v jq >/dev/null 2>&1; then
  bad "cannot check settings.json without jq"
else
  expected=$(jq -s -f "$SCRIPT_DIR/lib/merge-settings.jq" "$SRC/settings.base.json" "$local_settings" 2>/dev/null)
  if [ -f "$CLAUDE_HOME/settings.json" ] && [ "$expected" = "$(cat "$CLAUDE_HOME/settings.json")" ]; then
    ok "settings.json matches settings.base.json + settings.local.json"
  else
    bad "settings.json has drifted from the generated version. Move local changes into $local_settings, then run scripts/bootstrap.sh"
  fi
fi

echo "denylist:"
denylist="$CONF/denylist.txt"
if [ ! -f "$denylist" ]; then
  bad "$denylist missing. Run scripts/bootstrap.sh, then add your terms"
else
  terms=$(tr -d '\r' <"$denylist" | sed 's/^[[:space:]]*//' | grep -v '^#' | grep -c -v '^$' || true)
  if [ "${terms:-0}" -gt 0 ]; then
    ok "$terms term(s) in $denylist"
  else
    meh "$denylist has no terms yet. Add employer names, internal domains, emails, usernames and home paths"
  fi
fi

echo
if [ "$fails" -gt 0 ]; then
  echo "doctor: $fails problem(s), $warns warning(s)."
  exit 1
fi
echo "doctor: clean, $warns warning(s)."
