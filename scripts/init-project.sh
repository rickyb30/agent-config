#!/usr/bin/env bash
# Set an existing project up for the pipeline: create the docs folders and write
# .claude/pipeline.json. Run it yourself, from a terminal, in the project.
#
#   init-project.sh [options] [PROJECT_DIR]
#
#   (no options)                 detect likely source folders and ask before writing
#   --source-paths "src,tests"   protect exactly these folders
#   --all                        protect everything except docs/ and .claude/
#   --allow-deploy "CMD, CMD"    commands that change a live environment and that
#                                agents may run, e.g. "dbt build --target dev"
#   --yes                        accept the detected folders without asking
#   --dry-run                    print what would be written
#
# Existing files are never overwritten. If .claude/pipeline.json already exists the
# script shows it, creates any missing folders, and leaves the file alone.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"

# Folder names that usually hold code, infrastructure or data logic.
CANDIDATES="src lib app apps packages services functions tests test infra infrastructure terraform modules bicep models macros seeds snapshots dbt sql migrations notebooks jobs pipelines workflows dags"
FOLDERS="docs/architecture docs/research docs/plans docs/reviews docs/adr docs/knowledge/inbox docs/knowledge/patterns docs/knowledge/lessons docs/knowledge/references"

source_paths=""
have_source_paths=0
all=0
allow_deploy=""
yes=0
dry=0
dir=.
while [ $# -gt 0 ]; do
  case "$1" in
    --source-paths)
      [ $# -ge 2 ] || die "--source-paths needs a value, for example --source-paths \"src,tests\""
      source_paths="$2"
      have_source_paths=1
      shift
      ;;
    --allow-deploy)
      [ $# -ge 2 ] || die "--allow-deploy needs a value, for example --allow-deploy \"dbt build --target dev\""
      allow_deploy="$2"
      shift
      ;;
    --all) all=1 ;;
    --yes | -y) yes=1 ;;
    --dry-run) dry=1 ;;
    -h | --help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*) die "unknown option: $1 (try --help)" ;;
    *) dir="$1" ;;
  esac
  shift
done

# The configuration file is a human decision, so an agent session may not run this.
if [ -n "${CLAUDECODE:-}" ]; then
  die "run this yourself in a terminal, not through Claude Code: it writes .claude/pipeline.json, which only a person may create."
fi

command -v jq >/dev/null 2>&1 || die "jq is required. Install it with: $(install_hint jq)"
[ -d "$dir" ] || die "no such directory: $dir"
cd "$dir"
[ "$all" -eq 1 ] && [ "$have_source_paths" -eq 1 ] && die "use either --all or --source-paths, not both"
git rev-parse --show-toplevel >/dev/null 2>&1 || warn "$(pwd) is not a git repository; continuing anyway"

config=.claude/pipeline.json

make_folders() {
  local folder made=0
  for folder in $FOLDERS; do
    [ -d "$folder" ] && continue
    made=$((made + 1))
    if [ "$dry" -eq 1 ]; then
      info "would create $folder/"
    else
      mkdir -p "$folder"
      : >"$folder/.gitkeep"
    fi
  done
  if [ ! -f docs/knowledge/INDEX.md ]; then
    made=$((made + 1))
    if [ "$dry" -eq 1 ]; then
      info "would create docs/knowledge/INDEX.md"
    else
      cat >docs/knowledge/INDEX.md <<'EOF'
# Knowledge index

One line per accepted entry. Agents read this file first and open an entry only when
its summary or tags match the task. Only a person edits this file.

| Path | Summary | Tags |
| --- | --- | --- |
EOF
    fi
  fi
  [ "$made" -eq 0 ] || [ "$dry" -eq 1 ] || info "created $made folder(s) and file(s) under docs/"
}

if [ -f "$config" ]; then
  info "$config already exists and was left unchanged:"
  sed 's/^/    /' "$config"
  make_folders
  exit 0
fi

# Decide which folders the approval gate protects.
if [ "$all" -eq 0 ] && [ "$have_source_paths" -eq 0 ]; then
  detected=""
  for name in $CANDIDATES; do
    if [ -d "$name" ]; then detected="${detected:+$detected,}$name"; fi
  done
  if [ "$yes" -eq 1 ] || [ ! -t 0 ]; then
    [ -n "$detected" ] || die "no familiar source folders found here. Pass --source-paths \"a,b\" or --all."
    source_paths="$detected"
  else
    info "The approval gate blocks agents from writing to the folders you protect until"
    info "you have approved a design and a plan."
    if [ -n "$detected" ]; then
      info "Folders found here that look like source: $detected"
      printf 'Protect these? [Enter = yes | type your own list, e.g. src,tests | all = everything except docs/ and .claude/] '
    else
      info "No familiar source folders were found here."
      printf 'Folders to protect [type a list, e.g. src,tests | all = everything except docs/ and .claude/] '
    fi
    read -r answer
    case "$answer" in
      "")
        [ -n "$detected" ] || die "nothing to protect. Run again with a list, or with --all."
        source_paths="$detected"
        ;;
      all | ALL | All) all=1 ;;
      *) source_paths="$answer" ;;
    esac
    if [ -z "$allow_deploy" ]; then
      info "Agents are blocked from commands that change a live environment (apply, deploy,"
      info "destroy, warehouse writes). List any they may run here, or leave empty."
      printf 'Allowed deploy commands [Enter = none | e.g. dbt build --target dev, terraform apply] '
      read -r allow_deploy
    fi
  fi
fi

json=$(jq -n --arg paths "$source_paths" --arg deploy "$allow_deploy" --argjson all "$all" '
  def clean: map(gsub("^\\s+|\\s+$"; "")) | map(select(. != ""));
  ($paths | split(",") | clean | map(sub("^\\./"; "") | sub("/+$"; "")) | map(select(. != ""))) as $p
  | ($deploy | split(",") | clean) as $d
  | (if $all == 1 or ($p | length) == 0 then {} else {source_paths: $p} end)
    + (if ($d | length) > 0 then {allow_deploy: $d} else {} end)')

if [ "$all" -eq 0 ]; then
  for name in $(printf '%s' "$json" | jq -r '(.source_paths // [])[]'); do
    [ -d "$name" ] || warn "'$name' does not exist yet; it will be protected once created"
  done
fi

if [ "$dry" -eq 1 ]; then
  info "would write $config:"
  printf '%s\n' "$json" | sed 's/^/    /'
  make_folders
  exit 0
fi

mkdir -p .claude
printf '%s\n' "$json" >"$config"
info "wrote $config:"
sed 's/^/    /' "$config"
make_folders

info ""
info "Next, in a Claude Code session in this project:"
info "  1. Talk a design through, then /rb-design <name>"
info "  2. /rb-intake and /rb-research on the file it writes"
info "  3. Set status: approved in the design yourself, then /rb-draft-plan"
[ -f CLAUDE.md ] || info "Tip: this project has no CLAUDE.md. Add one with the stack and the commands that run its checks."
info "To change what is protected later, edit $config in your editor."
