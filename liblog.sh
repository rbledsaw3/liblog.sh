# liblog.sh — lightweight logging for bash
# Usage:
#   source "/path/to/liblog.sh"
#   LOG_LEVEL=DEBUG LOG_TS_FMT="%F %T"  # optional env overrides
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
  echo "liblog.sh must be sourced by bash (uses namerefs)." >&2
  return 1 2>/dev/null
fi

: "${LOG_LEVEL:=INFO}"              # ERROR,WARN,INFO,DEBUG,TRACE
: "${LOG_TS_FMT:=%Y-%m-%d %H:%M:%S}"
: "${LOG_FD:=2}"                    # where to write logs (default: stderr)

_log_level_num() {
  case "${1^^}" in
    ERROR|ERR) echo 0 ;;
    WARN|WARNING) echo 1 ;;
    INFO|INF) echo 2 ;;
    DEBUG|DBG) echo 3 ;;
    TRACE|TRC) echo 4 ;;
    *) echo 2 ;;
  esac
}

_log_should_log() {
  [ "$(_log_level_num "$1")" -le "$(_log_level_num "${LOG_LEVEL}")" ]
}

_log_ts() { date +"${LOG_TS_FMT}"; }

log() {
  local lvl="${1:-INFO}"; shift || true
  local proc="${1:-main}"; shift || true
  local msg="$*"
  if _log_should_log "$lvl"; then
    printf '%s [%s]: %s - %s\n' "$(_log_ts)" "${lvl^^}" "$proc" "$msg" >&"${LOG_FD}"
  fi
}

loge(){ log ERROR "$@"; }
logw(){ log WARN  "$@"; }
logi(){ log INFO  "$@"; }
logd(){ log DEBUG "$@"; }
logt(){ log TRACE "$@"; }

# Increment a counter var and log every N times.
# Example:
#   local i=0
#   log_counted i 100 INFO dumper "processed $i/$total"
log_counted(){
  local -n _cntr="$1"; shift
  local every="$1"; shift
  ((_cntr++))
  if (( every>0 && _cntr % every == 0 )); then
    log "$@"
  fi
}

# Log start/finish (and errors) while running a command.
# Example: log_time INFO fetch "fetching deps" -- npm ci
log_time(){
  local lvl="$1"; shift
  local proc="$1"; shift
  local desc="$1"; shift  # text before --
  if [[ "$1" == "--" ]]; then shift; fi
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

