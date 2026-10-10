#!/usr/bin/env bash
# PreToolUse hook (Bash).
#
# Blocks shell commands that change a live environment: infrastructure apply and
# destroy, cloud CLI calls that create, change or delete resources, warehouse SQL that
# writes, and deploys. Reading, validating and planning stay allowed, so an agent can
# run `terraform plan` or list resources but a human makes the change.
#
# A project can allow specific commands in .claude/pipeline.json (a human-only file):
#   { "allow_deploy": ["terraform apply", "dbt build --target dev"] }
# Each entry is a command prefix, compared from the tool name onwards.
#
# This is a guard against drift, not a sandbox: it reads the command text only. The
# control that actually holds is giving the agent read-only cloud credentials.
set -u

HOOK_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HOOK_DIR/lib/common.sh"

need_jq
input=$(cat)

[ "$(printf '%s' "$input" | jq -r '.tool_name // empty')" = Bash ] || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[ -n "$cmd" ] || exit 0

proj="${CLAUDE_PROJECT_DIR:-}"
[ -n "$proj" ] || proj=$(printf '%s' "$input" | jq -r '.cwd // empty')
config="${proj%/}/.claude/pipeline.json"

# Whole-word verbs that change something, per tool family.
V_IAC="apply destroy import taint untaint force-unlock"
V_PULUMI="up destroy refresh import cancel"
V_CDK="deploy destroy bootstrap"
V_AZD="up deploy provision down"
V_SAM="deploy delete sync"
V_AZ="create delete update set start stop restart deallocate deploy purge remove add import restore assign regenerate rotate upload invoke execute cancel failover swap scale upgrade apply grant revoke move run-command"
V_DATABRICKS="create delete deploy destroy run run-now submit reset update edit start restart stop cancel import import-dir rm cp mv mkdirs mkdir put put-secret delete-secret permanent-delete install uninstall patch set set-permissions update-permissions repair-run sync"
V_SNOW="deploy create drop execute copy remove run upgrade teardown publish"
V_DBT="run build seed snapshot run-operation clone retry"
V_KUBECTL="apply delete create replace patch scale rollout drain cordon uncordon edit set label annotate taint exec cp run expose autoscale"
V_HELM="install upgrade uninstall rollback delete"
# For aws and gcloud an operation is a verb or starts with one (delete-stack, set-iam-policy).
P_CLOUD="create delete put update modify terminate run start stop reboot attach detach associate disassociate deploy execute invoke send publish remove rm rb mb mv cp sync set register deregister enable disable tag untag restore reset revoke authorize import apply cancel purge rotate add write batch-write transact-write upload copy replace release allocate assign unassign accept reject share grant resize patch submit move rollback promote restart"
SQL_WRITE='(^|[^a-z_])(insert|update|delete|merge|create|alter|drop|truncate|grant|revoke|copy[[:space:]]+into|put|remove|undrop|call|execute)([^a-z_]|$)'

matched=""

# has_word "WORDS" ARGS... -> true when a non-option argument is one of WORDS
has_word() {
  local words="$1" arg
  shift
  for arg in "$@"; do
    case "$arg" in -*) continue ;; esac
    case " $words " in
      *" $arg "*)
        matched="$arg"
        return 0
        ;;
    esac
  done
  return 1
}

# has_prefix "VERBS" ARGS... -> true when a non-option argument is VERB or VERB-something
has_prefix() {
  local verbs="$1" arg verb
  shift
  for arg in "$@"; do
    case "$arg" in -*) continue ;; esac
    for verb in $verbs; do
      case "$arg" in
        "$verb" | "$verb"-*)
          matched="$arg"
          return 0
          ;;
      esac
    done
  done
  return 1
}

allowed_by_project() {
  local normalized="$1" entry
  [ -f "$config" ] || return 1
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    case "$normalized" in
      "$entry" | "$entry "*) return 0 ;;
    esac
  done <<EOF
$(jq -r '(.allow_deploy // [])[]' "$config" 2>/dev/null)
EOF
  return 1
}

# check_segment "one simple command" -> denies when it changes a live environment
check_segment() {
  local seg="$1" tool normalized lowered rest
  set -f
  # shellcheck disable=SC2086
  set -- $seg
  set +f
  while [ $# -gt 0 ]; do
    case "$1" in
      [A-Za-z_]*=*) shift ;;
      sudo | env | time | command | exec | nohup | xargs) shift ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 0
  tool="${1##*/}"
  shift

  case "$tool" in
    bash | sh | zsh | eval)
      while [ $# -gt 0 ]; do
        case "$1" in -*) shift ;; *) break ;; esac
      done
      rest="$*"
      rest="${rest//\"/}"
      rest="${rest//\'/}"
      [ -n "$rest" ] && check_segment "$rest"
      return 0
      ;;
  esac

  normalized="$tool${*:+ $*}"
  matched=""
  case "$tool" in
    terraform | tofu | terragrunt)
      has_word "$V_IAC" "$@" ||
        { has_word "state" "$@" && has_word "rm mv push" "$@"; } ||
        { has_word "workspace" "$@" && has_word "delete" "$@"; } || return 0
      ;;
    pulumi)
      has_word "$V_PULUMI" "$@" || { has_word "stack" "$@" && has_word "rm" "$@"; } || return 0
      ;;
    cdk | cdktf) has_word "$V_CDK" "$@" || return 0 ;;
    azd) has_word "$V_AZD" "$@" || return 0 ;;
    sam) has_word "$V_SAM" "$@" || return 0 ;;
    az)
      case "${1:-}" in login | logout | configure | version | find | account | extension | bicep) return 0 ;; esac
      has_word "$V_AZ" "$@" || return 0
      ;;
    aws)
      has_word "configure sso sts help" "$@" && return 0
      has_prefix "$P_CLOUD" "$@" || return 0
      ;;
    gcloud | gsutil | bq)
      case "${1:-}" in auth | config | help | version | info) return 0 ;; esac
      has_prefix "$P_CLOUD" "$@" || return 0
      ;;
    databricks)
      case "${1:-}" in auth | configure | version | help) return 0 ;; esac
      has_word "$V_DATABRICKS" "$@" || return 0
      ;;
    snow | snowsql)
      lowered=$(printf '%s' "$normalized" | lower)
      if [[ "$lowered" =~ $SQL_WRITE ]]; then
        matched="SQL that writes"
      else
        case " $* " in
          *" -f "* | *" --filename "* | *" --filename="*) matched="a SQL file this hook cannot inspect" ;;
          *) has_word "$V_SNOW" "$@" || return 0 ;;
        esac
      fi
      ;;
    dbt) has_word "$V_DBT" "$@" || return 0 ;;
    kubectl | oc) has_word "$V_KUBECTL" "$@" || return 0 ;;
    helm) has_word "$V_HELM" "$@" || return 0 ;;
    *) return 0 ;;
  esac

  allowed_by_project "$normalized" && return 0
  hook_deny "Blocked: '$normalized' changes a live environment ($matched). Read, validate and plan commands are allowed; a human runs the change, or allows this command for the project under allow_deploy in .claude/pipeline.json."
}

# Split a compound command into simple commands and check each one.
flat="$cmd"
flat="${flat//&&/;}"
flat="${flat//||/;}"
flat="${flat//\$(/;}"
flat="${flat//|/;}"
flat="${flat//\`/;}"
flat="${flat//(/;}"
flat="${flat//)/;}"
while IFS= read -r segment; do
  [ -n "$segment" ] || continue
  check_segment "$segment"
done <<EOF
$(printf '%s\n' "$flat" | tr ';' '\n')
EOF
exit 0
