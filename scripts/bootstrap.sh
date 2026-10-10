#!/usr/bin/env bash
# Install this repository into ~/.claude. Idempotent: a second run changes nothing.
#
#   scripts/bootstrap.sh              link the current checkout
#   scripts/bootstrap.sh --ref v0.1.0 check out that tag (detached) first, then link
#   scripts/bootstrap.sh --dry-run    print what would change
#
# What it touches:
#   ~/.claude/CLAUDE.md                              symlink
#   ~/.claude/{agents,skills,commands,hooks}/<entry> one symlink per entry; anything
#                                                    else in those folders is left alone
#   ~/.claude/settings.json                          generated: settings.base.json merged
#                                                    with ~/.config/agent-config/settings.local.json
# Anything it would replace is moved to ~/.claude/backups/agent-config/<timestamp>/ first.
#
# Environment overrides (used by tests): CLAUDE_HOME, AGENT_CONFIG_HOME.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"
REPO=$(cd "$SCRIPT_DIR/.." && pwd -P)
SRC="$REPO/claude"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CONF="${AGENT_CONFIG_HOME:-$HOME/.config/agent-config}"

ref=""
dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ref)
      [ $# -ge 2 ] || die "--ref needs a tag, for example --ref v0.1.0"
      ref="$2"
      shift
      ;;
    --dry-run) dry=1 ;;
    -h | --help)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

command -v jq >/dev/null 2>&1 || die "jq is required. Install it with: $(install_hint jq)"
command -v git >/dev/null 2>&1 || die "git is required. Install it with: $(install_hint git)"

if is_wsl; then
  case "$REPO" in
    /mnt/*) die "this checkout is on the Windows filesystem ($REPO). Clone it inside the Linux filesystem, for example ~/code/." ;;
  esac
fi

# --ref: move the checkout to a tag, then re-run the script from that tag.
if [ -n "$ref" ]; then
  git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || die "$REPO is not a git checkout, cannot use --ref"
  [ -z "$(git -C "$REPO" status --porcelain)" ] || die "the checkout has uncommitted changes, refusing to switch to $ref"
  if git -C "$REPO" remote get-url origin >/dev/null 2>&1; then
    git -C "$REPO" fetch --quiet --tags origin || warn "could not fetch from origin, using local tags"
  fi
  git -C "$REPO" rev-parse --verify --quiet "refs/tags/$ref^{commit}" >/dev/null || die "no such tag: $ref"
  if [ "$dry" -eq 1 ]; then
    info "would: check out tag $ref (detached) and bootstrap from it"
    exit 0
  fi
  git -C "$REPO" checkout --quiet --detach "refs/tags/$ref"
  info "checked out $ref (detached)"
  exec "${BASH:-bash}" "$SCRIPT_DIR/bootstrap.sh"
fi

STAMP=$(timestamp)
BACKUP="$CLAUDE_HOME/backups/agent-config/$STAMP"
changes=0

note() {
  changes=$((changes + 1))
  if [ "$dry" -eq 1 ]; then info "would: $*"; else info "$*"; fi
}

# backup PATH: move PATH into the backup folder, keeping its position relative to CLAUDE_HOME.
backup() {
  local path="$1" rel dest
  rel="${path#"$CLAUDE_HOME"/}"
  dest="$BACKUP/$rel"
  note "back up $path -> $dest"
  [ "$dry" -eq 1 ] && return 0
  mkdir -p "$(dirname "$dest")"
  mv "$path" "$dest"
}

# link_one SRC DST: make DST a symlink to SRC, backing up whatever was there.
link_one() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return 0
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    backup "$dst"
  fi
  note "link $dst -> $src"
  [ "$dry" -eq 1 ] && return 0
  ln -s "$src" "$dst"
}

ensure_dir() {
  local d="$1"
  [ -d "$d" ] && return 0
  if [ -e "$d" ] || [ -L "$d" ]; then backup "$d"; fi
  note "create $d"
  [ "$dry" -eq 1 ] && return 0
  mkdir -p "$d"
}

ensure_dir "$CLAUDE_HOME"
link_one "$SRC/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md"

for d in agents skills commands hooks; do
  ensure_dir "$CLAUDE_HOME/$d"
  for entry in "$SRC/$d"/*; do
    [ -e "$entry" ] || continue
    link_one "$entry" "$CLAUDE_HOME/$d/$(basename "$entry")"
  done
  # Remove links left behind by entries this repository no longer ships.
  for existing in "$CLAUDE_HOME/$d"/*; do
    [ -L "$existing" ] || continue
    target=$(readlink "$existing")
    case "$target" in
      "$SRC"/*)
        if [ ! -e "$target" ]; then
          note "remove stale link $existing"
          [ "$dry" -eq 1 ] || rm "$existing"
        fi
        ;;
    esac
  done
done

# Machine-local files live outside ~/.claude and outside this repository.
ensure_dir "$CONF"
local_settings="$CONF/settings.local.json"
out="$CLAUDE_HOME/settings.json"
if [ ! -f "$local_settings" ]; then
  if [ -f "$out" ] && [ ! -L "$out" ] && jq -e 'type == "object"' "$out" >/dev/null 2>&1; then
    note "seed $local_settings from the existing $out"
    [ "$dry" -eq 1 ] || cp "$out" "$local_settings"
  else
    note "create empty $local_settings"
    [ "$dry" -eq 1 ] || printf '{}\n' >"$local_settings"
  fi
fi

denylist="$CONF/denylist.txt"
if [ ! -f "$denylist" ]; then
  note "create denylist template $denylist"
  if [ "$dry" -eq 0 ]; then
    cat >"$denylist" <<'EOF'
# Terms that must never appear in a public repository. One per line, matched
# case-insensitively as plain text. This file stays on this machine: never commit it.
#
# Add: employer and client names, internal domains, work email addresses,
# usernames, and absolute home paths.
EOF
    chmod 600 "$denylist"
  fi
fi

# settings.json is generated, so a hand edit or a /config change would be lost here.
# The previous file is always backed up and a warning says so.
if [ -f "$local_settings" ]; then
  jq -e 'type == "object"' "$local_settings" >/dev/null 2>&1 || die "$local_settings is not a JSON object"
  merged=$(mktemp "${TMPDIR:-/tmp}/settings.XXXXXX")
  jq -s -f "$SCRIPT_DIR/lib/merge-settings.jq" "$SRC/settings.base.json" "$local_settings" >"$merged"
  if [ -f "$out" ] && [ ! -L "$out" ] && cmp -s "$merged" "$out"; then
    rm -f "$merged"
  else
    if [ -e "$out" ] || [ -L "$out" ]; then
      warn "$out differs from the generated settings. Keep machine-specific settings in $local_settings."
      backup "$out"
    fi
    note "write $out (settings.base.json merged with settings.local.json)"
    if [ "$dry" -eq 1 ]; then rm -f "$merged"; else mv "$merged" "$out"; fi
  fi
else
  note "write $out (settings.base.json merged with settings.local.json)"
fi

# Pre-commit scans for this repository itself.
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  if [ "$(git -C "$REPO" config --local --get core.hooksPath || true)" != ".githooks" ]; then
    note "enable git pre-commit scans in $REPO (core.hooksPath=.githooks)"
    [ "$dry" -eq 1 ] || git -C "$REPO" config --local core.hooksPath .githooks
  fi
fi

if [ "$changes" -eq 0 ]; then
  info "bootstrap: already up to date, nothing changed."
else
  info "bootstrap: $changes change(s)$([ "$dry" -eq 1 ] && echo ' would be made (dry run)')."
  [ "$dry" -eq 1 ] || info "next: scripts/doctor.sh"
fi
