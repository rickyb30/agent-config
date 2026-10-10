#!/usr/bin/env bash
# Portable helpers shared by scripts/. Target: bash 3.2 (macOS) and bash 5 (Linux/WSL).
# No associative arrays, no readarray, no GNU-only flags.

info() { printf '%s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# os_kind -> macos | wsl | linux | unknown
os_kind() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then echo wsl; else echo linux; fi
      ;;
    *) echo unknown ;;
  esac
}

is_wsl() { [ "$(os_kind)" = wsl ]; }

# realpath_p PATH -> absolute physical path (replacement for readlink -f).
# The final component does not need to exist; its parent does.
realpath_p() {
  local target="$1" dir base link n=0
  [ -n "$target" ] || return 1
  while [ -L "$target" ]; do
    n=$((n + 1))
    [ "$n" -le 40 ] || return 1
    link=$(readlink "$target") || return 1
    case "$link" in
      /*) target="$link" ;;
      *) target="$(dirname "$target")/$link" ;;
    esac
  done
  if [ -d "$target" ]; then
    (cd "$target" 2>/dev/null && pwd -P)
    return
  fi
  dir=$(dirname "$target")
  base=$(basename "$target")
  dir=$(cd "$dir" 2>/dev/null && pwd -P) || return 1
  printf '%s/%s\n' "${dir%/}" "$base"
}

# sed_inplace SED_EXPRESSION FILE (replacement for sed -i, which differs on BSD and GNU).
sed_inplace() {
  local expr="$1" file="$2" tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/sed_inplace.XXXXXX") || return 1
  if sed "$expr" "$file" >"$tmp"; then
    cat "$tmp" >"$file"
    rm -f "$tmp"
  else
    rm -f "$tmp"
    return 1
  fi
}

# timestamp -> 20260131-235959 (no date -d needed)
timestamp() { date +%Y%m%d-%H%M%S; }

# install_hint TOOL -> the command that installs TOOL on this machine
install_hint() {
  local tool="$1" pkg="$1"
  case "$(os_kind)" in
    macos)
      case "$tool" in python3) pkg=python ;; esac
      echo "brew install $pkg"
      ;;
    *)
      case "$tool" in
        gitleaks) echo "sudo apt-get install -y gitleaks   # or a release binary from the gitleaks project" ;;
        *) echo "sudo apt-get install -y $pkg" ;;
      esac
      ;;
  esac
}
