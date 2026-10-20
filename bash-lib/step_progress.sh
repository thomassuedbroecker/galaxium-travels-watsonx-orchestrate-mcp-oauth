#!/usr/bin/env bash
# Shared bash step progress helper, sourced by all automation scripts (do not run it directly).
#
# run_step <timeout-seconds> <label> <command...>
#   - prints the step, then a heartbeat every 10 s while the command runs
#   - after 60 s without a result it prints a status message ("still working / what to do")
#   - stops the command after the timeout and prints the retry information
#   - the command output is shown live; STEP_OUT=<file> run_step ... sends stdout to a file instead
#   - stdin is passed through, so "printf 'y\n' | run_step ..." works
#   - the exit code is the command's (124 on timeout)
# The command line is never printed (it may contain secrets), only the label.

_PS_BLUE='\033[0;34m'; _PS_YELLOW='\033[1;33m'; _PS_GREEN='\033[0;32m'; _PS_RED='\033[0;31m'; _PS_NC='\033[0m'

step_info() { echo -e "\n${_PS_BLUE}========================================${_PS_NC}\n${_PS_YELLOW} $* ${_PS_NC}"; }

run_step() {
  local limit="$1" label="$2" start rc waited=0 pid
  shift 2
  start=$(date +%s)
  echo -e "${_PS_YELLOW}>>${_PS_NC} ${label} (waits up to ${limit}s)"
  if [[ -n "${STEP_OUT:-}" ]]; then
    "$@" <&0 >"${STEP_OUT}" &
  else
    "$@" <&0 &
  fi
  pid=$!
  while kill -0 "${pid}" 2>/dev/null; do
    sleep 1; waited=$((waited + 1))
    if (( waited >= limit )); then
      kill "${pid}" 2>/dev/null; sleep 1; kill -9 "${pid}" 2>/dev/null || true
      wait "${pid}" 2>/dev/null || true
      echo -e "${_PS_RED}TIMEOUT${_PS_NC} after ${limit}s: ${label}" >&2
      echo "   Retry: run the same script again. Finished steps are safe to repeat. A cold start of IBM Code Engine or a slow service is the usual cause." >&2
      return 124
    fi
    if (( waited % 60 == 0 )); then
      echo -e "   ${_PS_YELLOW}NO RESPONSE for ${waited}s${_PS_NC}: ${label}. Still working, waiting up to ${limit}s. If it times out, run the script again."
    elif (( waited % 10 == 0 )); then
      echo "   ... still running (${waited}s): ${label}"
    fi
  done
  wait "${pid}" && rc=0 || rc=$?
  if (( rc == 0 )); then
    echo -e "${_PS_GREEN}OK${_PS_NC} ${label} ($(( $(date +%s) - start ))s)"
  else
    echo -e "${_PS_RED}FAILED${_PS_NC} (exit ${rc}, $(( $(date +%s) - start ))s): ${label}" >&2
    echo "   Retry: fix the cause shown above, then run the same script again." >&2
  fi
  return "${rc}"
}
