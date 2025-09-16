# liblog.sh — lightweight logging for bash
# Usage:
#   source "/path/to/liblog.sh"
#   LOG_LEVEL=DEBUG LOG_COLOR=auto LOG_TS_FMT="%F %T"  # optional env overrides
#
# API:
#   log <LEVEL> <PROCESS_NAME> <message...>
#   loge/logw/logi/logd/logt <PROCESS_NAME> <message...>
#   log_counted <counter_var> <everyN> <LEVEL> <PROCESS> <message...>
#   log_time <LEVEL> <PROCESS> <desc> -- <command> [args...]
#
#   (c) 2025 Robert Bledsaw

# Guard to prevent direct execution and multiple sourcing.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "liblog.sh must be sourced by bash." >&2
  return 1 2>/dev/null
fi

: "${LOG_LEVEL:=INFO}"              # ERROR,WARN,INFO,DEBUG,TRACE
: "${LOG_TS_FMT:=%Y-%m-%d %H:%M:%S}"
: "${LOG_FD:=2}"                    # where to write logs (default: stderr)
: "${LOG_COLOR:=auto}"              # auto,always,never (respects NO_COLOR; FORCE_COLOR implies always)

__LOG_COLOR_ENABLED=""
__CLR_RESET=""; __CLR_ERR=""; __CLR_WRN=""; __CLR_DBG=""; __CLR_TRC=""

function _log_is_tty() { [[ -t "${LOG_FD}" ]]; }

function _log_enable_color() {
    if [[ "${LOG_COLOR}" == "never" || -n "${NO_COLOR:-}" ]]; then
        __LOG_COLOR_ENABLED="0"
        return
    fi
    if [[ "${LOG_COLOR}" == "always" || -n "${FORCE_COLOR:-}" ]]; then
        __LOG_COLOR_ENABLED="1"
    else
        _log_is_tty && __LOG_COLOR_ENABLED="1" || __LOG_COLOR_ENABLED="0"
    fi
}

function _log_init_palette() {
    _log_enable_color
    if [[ "$__LOG_COLOR_ENABLED" != "1" ]]; then return; fi

    local colors reset red yellow gray faint
    colors="$(tput colors 2>/dev/null || echo 0)"
    reset="$(tput sgr0 2>/dev/null || printf '\e[0m')"
    red="$(tput setaf 1 2>/dev/null || printf '\e[31m')"
    yellow="$(tput setaf 3 2>/dev/null || printf '\e[33m')"

    if command -v tput >/dev/null 2>&1 && tput smso >/dev/null 2>&1; then :; fi
    faint=$'\e[2m'
    if (( colors >= 16 )); then
        gray="$(tput setaf 8 2>/dev/null || printf '\e[90m')"
    else
        gray="$faint"
    fi

    __CLR_RESET="$reset"
    __CLR_ERR="$red"
    __CLR_WRN="$yellow"
    __CLR_DBG="$gray"
    __CLR_TRC="$faint"
}
_log_init_palette

function _log_level_num() {
  case "${1^^}" in
    ERROR|ERR) echo 0 ;;
    WARN|WARNING) echo 1 ;;
    INFO|INF) echo 2 ;;
    DEBUG|DBG) echo 3 ;;
    TRACE|TRC) echo 4 ;;
    *) echo 2 ;;
  esac
}

function _log_should_log() {
  [ "$(_log_level_num "$1")" -le "$(_log_level_num "${LOG_LEVEL}")" ]
}

function _log_ts() { date +"${LOG_TS_FMT}"; }

function log() {
  local lvl="${1:-INFO}"; shift || true
  local proc="${1:-main}"; shift || true
  local msg="$*"
  local L="${lvl^^}"
  local tag="[${L}]"

  if ! _log_should_log "$lvl"; then return 0; fi

  if [[ "$__LOG_COLOR_ENABLED" == "1" ]]; then
    case "$L" in
      ERROR|ERR) tag="${__CLR_ERR}${tag}${__CLR_RESET}" ;;
      WARN|WARNING) tag="${__CLR_WRN}${tag}${__CLR_RESET}" ;;
      DEBUG|DBG) tag="${__CLR_DBG}${tag}${__CLR_RESET}" ;;
      TRACE|TRC) tag="${__CLR_TRC}${tag}${__CLR_RESET}" ;;
    esac
  fi

  printf '%s %s: %s - %s\n' "$(_log_ts)" "$tag" "$proc" "$msg" >&"${LOG_FD}"
}

function loge() { log ERROR "$@"; }
function logw() { log WARN  "$@"; }
function logi() { log INFO  "$@"; }
function logd() { log DEBUG "$@"; }
function logt() { log TRACE "$@"; }

# Increment a counter var and log every N times.
# Example:
#   local i=0
#   log_counted i 100 INFO dumper "processed $i/$total"
function log_counted() {
  local -n _cntr="$1"; shift
  local every="$1"; shift
  ((_cntr++))
  if (( every>0 && _cntr % every == 0 )); then
    log "$@"
  fi
}

# Log start/finish (and errors) while running a command.
# Example: log_time INFO fetch "fetching deps" -- npm ci
function log_time() {
  local lvl="$1"; shift
  local proc="$1"; shift
  local desc="$1"; shift
  [[ "$1" == "--" ]] && shift
  local start end elapsed rc
  start=$(date +%s)
  log "$lvl" "$proc" "start: $desc"
  "$@"; rc=$?
  end=$(date +%s); elapsed=$((end-start))
  if (( rc==0 )); then
    log "$lvl" "$proc" "done in ${elapsed}s: $desc"
  else
    loge "$proc" "FAILED in ${elapsed}s (rc=$rc): $desc"
  fi
  return $rc
}

