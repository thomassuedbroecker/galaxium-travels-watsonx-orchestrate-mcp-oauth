#!/usr/bin/env bash
# Inspect IBM Code Engine pods for the Galaxium Travels stack using kubectl.
#
# Usage (from any folder):
#   bash infrastructure/inspect_code_engine.sh [info|log|log-follow] [APP_NAME]
#
#   info        (default) show pods, deployments, configmaps for the project
#   log         dump the current log of APP_NAME to infrastructure/logs/<APP_NAME>_<timestamp>.log
#   log-follow  stream live logs for APP_NAME (Ctrl+C to stop)
#
# APP_NAME is optional for log / log-follow.
# When omitted, the script connects, lists the running pods and prompts you to
# pick one interactively.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-info}"
APP_NAME="${2:-}"          # empty = interactive pick after connect

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

fail()  { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
info()  { echo -e "\n${BLUE}========================================${NC}\n${YELLOW} $* ${NC}"; }

case "${ACTION}" in
  info|log|log-follow) ;;
  *) fail "unknown action '${ACTION}'. Use: info | log | log-follow" ;;
esac

# ── Load settings ──────────────────────────────────────────────────────────────
ENV_FILE="${SCRIPT_DIR}/.env"
LINKS_FILE="${SCRIPT_DIR}/deployment-links.env"

[[ -f "${ENV_FILE}" ]] \
  || fail "missing ${ENV_FILE}. Copy .env_template and set IBM_CLOUD_API_KEY."
set -a; source "${ENV_FILE}"; set +a

# deployment-links.env provides CE_PROJECT_NAME and IBM_CLOUD_REGION as defaults
if [[ -f "${LINKS_FILE}" ]]; then
  # only set variables that are not already set from .env
  while IFS='=' read -r key value; do
    [[ "${key}" =~ ^# ]] && continue
    [[ -z "${key}" ]]    && continue
    if [[ -z "${!key:-}" ]]; then
      declare "${key}=${value}"
    fi
  done < "${LINKS_FILE}"
fi

IBM_CLOUD_REGION="${IBM_CLOUD_REGION:-us-south}"
IBM_CLOUD_RESOURCE_GROUP="${IBM_CLOUD_RESOURCE_GROUP:-default}"
CE_PROJECT_NAME="${CE_PROJECT_NAME:-galaxium-travels-oauth2}"

# ── Prerequisites ──────────────────────────────────────────────────────────────
# kubectl install docs: https://kubernetes.io/docs/tasks/tools/
#   macOS:  brew install kubectl
#   Linux:  https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
#   Windows: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
for cmd in ibmcloud kubectl jq; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    case "${cmd}" in
      ibmcloud) hint="curl -fsSL https://clis.cloud.ibm.com/install/osx | sh" ;;
      kubectl)  hint="brew install kubectl  # macOS; see https://kubernetes.io/docs/tasks/tools/" ;;
      jq)       hint="brew install jq" ;;
    esac
    fail "'${cmd}' is not installed. Install: ${hint}"
  fi
done
ibmcloud plugin show code-engine >/dev/null 2>&1 \
  || fail "IBM Cloud Code Engine plugin missing. Install: ibmcloud plugin install code-engine"

# ── Log in and connect to the Code Engine project ─────────────────────────────
login_and_connect() {
  info "Log in to IBM Cloud"
  ibmcloud login --apikey "${IBM_CLOUD_API_KEY}" \
    -r "${IBM_CLOUD_REGION}" -g "${IBM_CLOUD_RESOURCE_GROUP}" -q

  info "Select Code Engine project: ${CE_PROJECT_NAME}"
  ibmcloud ce project select -n "${CE_PROJECT_NAME}"

  # Inject the project kubeconfig so kubectl talks to this CE project
  ibmcloud ce project select -n "${CE_PROJECT_NAME}" --kubecfg

  # The namespace is written into the kubeconfig by --kubecfg above.
  # Read it directly from the current context — no extra API call needed.
  CE_NAMESPACE="$(kubectl config view --minify \
                    -o jsonpath='{.contexts[0].context.namespace}' 2>/dev/null)"
  [[ -n "${CE_NAMESPACE}" ]] \
    || fail "could not read the Kubernetes namespace from the kubeconfig for project '${CE_PROJECT_NAME}'."
  echo "Code Engine project namespace: ${CE_NAMESPACE}"
}

# ── Interactive pod picker ─────────────────────────────────────────────────────
# Lists every running pod, extracts the CE app name (everything before the
# second-to-last dash-separated token that looks like a revision), and lets the
# user choose with a numbered bash `select` menu.
pick_app() {
  # Collect running pod names
  local pods=()
  while IFS= read -r line; do
    [[ -n "${line}" ]] && pods+=("${line}")
  done < <(kubectl get pods -n "${CE_NAMESPACE}" \
             --field-selector=status.phase=Running \
             -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

  [[ ${#pods[@]} -gt 0 ]] \
    || fail "no running pods found in namespace '${CE_NAMESPACE}'."

  echo ""
  echo "Running pods in project '${CE_PROJECT_NAME}':"
  echo ""

  # Build a display list: "<index>  <pod-name>" so the user sees the full name
  PS3=$'\nEnter pod number: '
  local chosen_pod
  select chosen_pod in "${pods[@]}"; do
    [[ -n "${chosen_pod}" ]] && break
    echo "Invalid selection — enter a number between 1 and ${#pods[@]}."
  done

  # Derive the CE app name: Code Engine pods are named
  #   <app-name>-<revision-suffix>-<random>
  # The app name is everything up to (but not including) the last two dash-
  # separated tokens, e.g.  galaxium-booking-mcp-00005-deployment-abcde
  #                       → galaxium-booking-mcp
  APP_NAME="$(echo "${chosen_pod}" | rev | cut -d'-' -f4- | rev)"
  echo "Selected app: ${APP_NAME}  (pod: ${chosen_pod})"
}

# ── Find the pod whose name starts with the CE application name ───────────────
# Code Engine names pods <app-name>-<revision>-<random>; grep for the app name
# as a prefix to avoid matching an unrelated app that contains the string.
find_pod() {
  local app="$1"
  local pod
  pod="$(kubectl get pods -n "${CE_NAMESPACE}" \
          --field-selector=status.phase=Running \
          -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
          | grep "^${app}-" | head -n 1)"
  [[ -n "${pod}" ]] \
    || fail "no running pod found for app '${app}' in namespace '${CE_NAMESPACE}'."
  echo "${pod}"
}

# ── Actions ───────────────────────────────────────────────────────────────────
kube_info() {
  info "Cluster overview for project '${CE_PROJECT_NAME}'"
  echo ""
  echo "--- pods ---"
  kubectl get pods        -n "${CE_NAMESPACE}"
  echo ""
  echo "--- deployments ---"
  kubectl get deployments -n "${CE_NAMESPACE}"
  echo ""
  echo "--- configmaps ---"
  kubectl get configmaps  -n "${CE_NAMESPACE}"
}

kube_log() {
  local app="$1"
  info "Pod log for app '${app}'"
  local pod
  pod="$(find_pod "${app}")"
  echo "Pod: ${pod}"

  mkdir -p "${SCRIPT_DIR}/logs"
  local ts
  ts="$(date +'%F_%H%M%S')"
  local log_file="${SCRIPT_DIR}/logs/${app}_${ts}.log"

  {
    echo "================================================"
    echo "App:       ${app}"
    echo "Pod:       ${pod}"
    echo "Namespace: ${CE_NAMESPACE}"
    echo "Captured:  ${ts}"
    echo "================================================"
    kubectl logs "${pod}" -n "${CE_NAMESPACE}"
  } | tee "${log_file}"
  echo ""
  echo "Log saved to: ${log_file}"
}

kube_log_follow() {
  local app="$1"
  info "Streaming live log for app '${app}' (Ctrl+C to stop)"
  local pod
  pod="$(find_pod "${app}")"
  echo "Pod: ${pod}"
  kubectl logs -f "${pod}" -n "${CE_NAMESPACE}"
}

# ── Main ───────────────────────────────────────────────────────────────────────
login_and_connect

# For log / log-follow: if no APP_NAME was given on the command line, prompt.
if [[ "${ACTION}" != "info" && -z "${APP_NAME}" ]]; then
  pick_app
fi

case "${ACTION}" in
  info)       kube_info ;;
  log)        kube_log        "${APP_NAME}" ;;
  log-follow) kube_log_follow "${APP_NAME}" ;;
esac
