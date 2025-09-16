# liblog.sh

Lightweight, dependency-free logging helpers for Bash scripts.

**Format:**

```
YYYY-MM-DD HH:MM:SS [LEVEL]: PROCESS_NAME - MESSAGE
```

* Logs to **stderr** by default.
* Level filtering (`ERROR` < `WARN` < `INFO` < `DEBUG` < `TRACE`).
* Theme-aware colors.
* Tiny API you can drop into any script.

---

## Install

### User install (no sudo)

Save the library (from your script or my snippet) to:

```
~/.local/lib/bash/liblog.sh
```

Then source it in your scripts:

```bash
# shellcheck source=/dev/null
source "$HOME/.local/lib/bash/liblog.sh"
```

### System-wide (ShellCheck-friendly path)

Install to:

```
/usr/local/lib/bash/liblog.sh
```

with something like:

```
sudo mkdir /usr/local/lib/bash
sudo cp ./liblog.sh /usr/local/lib/bash/
```

then:

```bash
source /usr/local/lib/bash/liblog.sh
```

> Requires **bash 4.3+** (uses `local -n` namerefs).

---

## Quick start

```bash
#!/usr/bin/env bash

source /usr/local/lib/bash/liblog.sh

LOG_LEVEL=INFO      # optional (default INFO)
LOG_COLOR=auto      # auto|always|never (default: auto)
LOG_TS_FMT="%F %T"  # 2025-09-16 13:37:00

logi setup "initializing"
logw config "missing optional env FOO; using defaults"
logd debug "this is verbose and only shows when LOG_LEVEL=DEBUG+"
loge failure "could not contact service (rc=7)"
```

**Example output:**

```
2025-09-16 12:34:22 [INFO]: setup - initializing
2025-09-16 12:34:22 [WARN]: config - missing optional env FOO; using defaults
```

---

## Log format

```
<timestamp> [<LEVEL>]: <PROCESS_NAME> - <MESSAGE>
```

* **Timestamp**: comes from `date +"$LOG_TS_FMT"`, default `"%Y-%m-%d %H:%M:%S"`.
* **LEVEL**: is uppercased.
* **PROCESS\_NAME**: logical phase (e.g., `fetch`, `upload`, `parser`, etc.).
* **MESSAGE** is the free-text description.

---

## Environment variables (all optional)

* `LOG_LEVEL`: minimum level to emit.

  * One of: `ERROR`, `WARN`, `INFO`, `DEBUG`, `TRACE` (default: `INFO`).
* `LOG_COLOR`: color policy (default: `auto`)

  * `auto`: color only when writing to a TTY (and supported)
  * `always`: force color (even when redirected)
  * `never`: disable color

  Also respects:

  * `NO_COLOR` → disables color
  * `FORCE_COLOR` → forces color
* `LOG_TS_FMT`: timestamp format passed to `date +...` (default: `%Y-%m-%d %H:%M:%S`).
* `LOG_FD`: numeric file descriptor to write logs to (default: `2` for stderr).

  * Set `LOG_FD=1` to log to stdout, or open your own FD.

---

## API

```bash
log   <LEVEL> <PROCESS_NAME> <message...>
loge  <PROCESS_NAME> <message...>   # LEVEL=ERROR
logw  <PROCESS_NAME> <message...>   # LEVEL=WARN
logi  <PROCESS_NAME> <message...>   # LEVEL=INFO
logd  <PROCESS_NAME> <message...>   # LEVEL=DEBUG
logt  <PROCESS_NAME> <message...>   # LEVEL=TRACE
```

`log_counted <counter_var> <everyN> <LEVEL> <PROCESS_NAME> <message...>`

Increments `<counter_var>` and logs every `everyN` iterations.

```bash
local i=0
while read -r path; do
  # ... work ...
  log_counted i 100 INFO dumper "processed $i files"
done < <(find . -type f)
```

`log_time <LEVEL> <PROCESS_NAME> <desc> -- <command> [args...]`

Logs start/finish, measures seconds, and logs failure with exit code if the command fails.

```bash
log_time INFO fetch "npm ci in web/" -- bash -lc 'cd web && npm ci'
# Emits:
# 2025-09-16 12:00:00 [INFO]: fetch - start: npm ci in web/
# 2025-09-16 12:00:05 [INFO]: fetch - done in 5s: npm ci in web/
```

---

## Color behavior

* Uses your terminal's theme via `tput setaf` standard palette:

  * `ERROR`=1 (red), `WARN`=3 (yellow/orange), etc.

* `DEBUG` uses **faint** (SGR 2) when possible; if 16-color is available, it prefers **bright black** (index 8) as a clearer gray.
* `INFO` is unstyled by default for readability across light/dark themes.
* `auto` disables colors when not a TTY; use `LOG_COLOR=always` to force colors in files/pipes.

### Force color to a log file:

```bash
exec 9> ./script.log
LOG_FD=9 LOG_COLOR=always LOG_LEVEL=DEBUG bash -lc '
    source /usr/local/lib/bash/liblog.sh
    logd debug "colored even when redirected"
    logw warn "warning in theme yellow/orange"
    loge error "error in theme red"
'
```

## Examples

### 1) Basic usage with levels

```bash
LOG_LEVEL=DEBUG
logi init "starting up"
logd scan "found 42 candidates"
loge io "failed to open /dev/sg0 (permission denied)"
```

**Output**

```
2025-09-16 12:40:00 [INFO]: init - starting up
2025-09-16 12:40:00 [DEBUG]: scan - found 42 candidates
2025-09-16 12:40:00 [ERROR]: io - failed to open /dev/sg0 (permission denied)
```

### 2) Progress logging in loops

```bash
source /usr/local/lib/bash/liblog.sh
LOG_LEVEL=INFO
local n=0
while IFS= read -r -d '' f; do
  # do work...
  log_counted n 250 INFO dumper "processed $n files"
done < <(find . -type f -print0)
```

**Output (every 250 files)**

```
2025-09-16 12:45:10 [INFO]: dumper - processed 250 files
2025-09-16 12:45:27 [INFO]: dumper - processed 500 files
```

### 3) Timing a command

```bash
log_time INFO build "compile release" -- make -j$(nproc) release
```

**Success**

```
2025-09-16 12:50:00 [INFO]: build - start: compile release
2025-09-16 12:50:42 [INFO]: build - done in 42s: compile release
```

**Failure**

```
2025-09-16 12:50:00 [INFO]: build - start: compile release
2025-09-16 12:50:05 [ERROR]: build - FAILED in 5s (rc=2): compile release
```

### 4) Redirect logs to a file (without mixing with stdout)

```bash
# Open FD 9 to a log file and send logs there
exec 9> "./script.log"
LOG_FD=9 LOG_LEVEL=DEBUG ./myscript > output.txt
```

**Result**

* `script.log` contains the logs.
* `output.txt` contains only the script’s stdout.

### 5) Custom timestamp format

```bash
LOG_TS_FMT='%H:%M:%S' logi short "compact timestamps"
# 12:55:33 [INFO]: short - compact timestamps
```

---

## Tips

* Logs go to **stderr** by default, so they won’t corrupt data you print to stdout.
* Use process names (`init`, `collector`, `tree`, `dumper`, `upload`, etc.) to segment phases.
* With `set -euo pipefail`, the helpers don’t suppress errors; `log_time` returns the wrapped command’s exit code.

---

## License

MIT (do whatever; attribution appreciated).

