#!/usr/bin/env bash
# Shared helper, sourced by the other scripts in this folder (do not run it directly).
# 1. activates the ADK virtual environment
# 2. loads .env
# 3. registers and activates the remote watsonx Orchestrate environment

WXO_ADK_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GALAXIUM_ENDPOINTS_FILE="${WXO_ADK_DIR}/../infrastructure/galaxium-endpoints.env"

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

wxo_info() { echo -e "\n${BLUE}========================================${NC}\n${YELLOW} $* ${NC}"; }
wxo_fail() { echo -e "${RED}ERROR: $*${NC}" >&2; return 1 2>/dev/null || exit 1; }
wxo_ok() { echo -e "${GREEN}OK${NC} $*"; }

# wxo_run <timeout-seconds> <label> <command...>: progress, 60 s status message, timeout, retry info.
# shellcheck disable=SC1091
source "${WXO_ADK_DIR}/../bash-lib/step_progress.sh"
wxo_run() { run_step "$@"; }

[[ -f "${WXO_ADK_DIR}/.venv/bin/activate" ]] \
  || wxo_fail "missing .venv. Run: bash watsonx-orchestrate-adk/wxo_install_adk.sh"
[[ -f "${WXO_ADK_DIR}/.env" ]] \
  || wxo_fail "missing .env. Run: cp watsonx-orchestrate-adk/.env_template watsonx-orchestrate-adk/.env"

# shellcheck disable=SC1091
source "${WXO_ADK_DIR}/.venv/bin/activate"
set -a; source "${WXO_ADK_DIR}/.env"; set +a

[[ -n "${WXO_API_KEY:-}" && "${WXO_API_KEY}" != "<YOUR_IBM_CLOUD_API_KEY>" ]] || wxo_fail "set WXO_API_KEY in .env"
[[ -n "${WXO_URL:-}" && "${WXO_URL}" != "<YOUR_SERVICE_INSTANCE_URL>" ]] || wxo_fail "set WXO_URL in .env"

# Remote instance only. The local Developer Edition must never be used.
[[ "${WXO_URL}" != *localhost* && "${WXO_URL}" != *127.0.0.1* ]] \
  || wxo_fail "WXO_URL points to a local Developer Edition. Only the remote watsonx Orchestrate instance is allowed."

[[ "${WXO_URL}" == *watson-orchestrate* ]] \
  || echo "WARNING: WXO_URL does not look like a watsonx Orchestrate URL (expected https://api.<region>.watson-orchestrate.cloud.ibm.com/instances/<ID>)." >&2

WXO_ENV_NAME="${WXO_ENV_NAME:-galaxium-remote}"

wxo_info "Activate the remote environment '${WXO_ENV_NAME}'"
# "env remove" asks for a confirmation when the environment is active. Answer it (y), otherwise it waits forever.
printf 'y\n' | STEP_OUT=/dev/null wxo_run 60 "env remove ${WXO_ENV_NAME} (ignored if it does not exist)" orchestrate env remove --name "${WXO_ENV_NAME}" || true
wxo_run 60 "env add ${WXO_ENV_NAME}" orchestrate env add --name "${WXO_ENV_NAME}" --url "${WXO_URL}"
wxo_run 120 "env activate ${WXO_ENV_NAME}" orchestrate env activate "${WXO_ENV_NAME}" --api-key "${WXO_API_KEY}"

# A failed activation leaves the previously active environment (e.g. "local") in place. Refuse to continue then.
active_line="$(orchestrate env list 2>/dev/null | sed -E 's/\x1b\[[0-9;]*m//g' | grep '(active)' || true)"
[[ "${active_line}" =~ ^[[:space:]]*${WXO_ENV_NAME}[[:space:]] ]] \
  || wxo_fail "'${WXO_ENV_NAME}' is not the active environment (active: ${active_line%%  *}). Stopping, no command is run against another environment."
wxo_ok "active environment: ${WXO_ENV_NAME}"
