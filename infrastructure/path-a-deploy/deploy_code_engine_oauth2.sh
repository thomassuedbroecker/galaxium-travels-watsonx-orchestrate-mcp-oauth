#!/usr/bin/env bash
# Deploy the Galaxium Travels OAuth2 stack (Keycloak + MCP server + APIs + web UIs)
# to IBM Code Engine with a minimal configuration.
#
# Usage (from any folder):
#   bash infrastructure/path-a-deploy/deploy_code_engine_oauth2.sh [deploy|prepare|endpoints]
#
#   deploy     (default) prepare + deploy + write galaxium-endpoints.env
#   prepare    clone the infrastructure repo and generate the deploy env file only
#   endpoints  re-read the Code Engine URLs and rewrite galaxium-endpoints.env
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
INFRA_REPO_URL="https://github.com/thomassuedbroecker/galaxium-travels-infrastructure-tsuedbro.git"
REPO_DIR="${INFRA_DIR}/galaxium-travels-infrastructure-tsuedbro"
CE_DIR="${REPO_DIR}/deployment/ibm-code-engine"
DEPLOY_ENV="${CE_DIR}/deploy.env.oauth2"
REALM_FILE="${REPO_DIR}/local-container/keycloak/realm/galaxium-realm.json"
ENDPOINTS_FILE="${INFRA_DIR}/galaxium-endpoints.env"
ACTION="${1:-deploy}"

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

fail() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
# shellcheck disable=SC1091
source "${INFRA_DIR}/../bash-lib/step_progress.sh"
info() { step_info "$@"; }

# ── Load the (optional) local settings ─────────────────────────────────────────
if [[ -f "${INFRA_DIR}/.env" ]]; then
  set -a; source "${INFRA_DIR}/.env"; set +a
fi

IBM_CLOUD_REGION="${IBM_CLOUD_REGION:-us-south}"
IBM_CLOUD_RESOURCE_GROUP="${IBM_CLOUD_RESOURCE_GROUP:-default}"
CE_PROJECT_NAME="${CE_PROJECT_NAME:-galaxium-travels-oauth2}"
INFRA_TAG="${INFRA_TAG:-v6.2.3}"

case "${ACTION}" in
  deploy|prepare|endpoints) ;;
  *) fail "unknown action '${ACTION}'. Use: deploy | prepare | endpoints" ;;
esac

# ── Helpers ────────────────────────────────────────────────────────────────────
require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command '$1' is not installed. $2"
}

generate_secret() {
  python3 -c "import secrets; print(secrets.token_hex($1))"
}

set_var() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}=" "${file}"; then
    sed -i.bak "s|^${key}=.*|${key}=${value}|" "${file}"
    rm -f "${file}.bak"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${file}"
  fi
}

ce_login_and_select_project() {
  [[ -n "${IBM_CLOUD_API_KEY:-}" && "${IBM_CLOUD_API_KEY}" != "<YOUR_IBM_CLOUD_API_KEY>" ]] \
    || fail "set IBM_CLOUD_API_KEY in ${INFRA_DIR}/.env (copy .env_template first)."
  STEP_OUT=/dev/null run_step 120 "ibmcloud login (${IBM_CLOUD_REGION}/${IBM_CLOUD_RESOURCE_GROUP})" \
    ibmcloud login --apikey "${IBM_CLOUD_API_KEY}" -r "${IBM_CLOUD_REGION}" -g "${IBM_CLOUD_RESOURCE_GROUP}" -q
}

check_prerequisites() {
  require_command git "Install git."
  require_command python3 "Install Python 3."
  if [[ "${ACTION}" != "prepare" ]]; then
    require_command ibmcloud "Install: curl -fsSL https://clis.cloud.ibm.com/install/osx | sh"
    require_command curl "Install curl."
    require_command jq "Install jq (brew install jq)."
    ibmcloud plugin show code-engine >/dev/null 2>&1 \
      || fail "IBM Cloud Code Engine plugin missing. Install: ibmcloud plugin install code-engine"
  fi
}

clone_infrastructure_repo() {
  info "Infrastructure repository (${INFRA_TAG})"
  if [[ ! -d "${REPO_DIR}/.git" ]]; then
    run_step 180 "git clone infrastructure repository" git clone "${INFRA_REPO_URL}" "${REPO_DIR}"
  fi
  run_step 120 "git fetch tags" git -C "${REPO_DIR}" fetch --tags --quiet
  # The realm file is patched with generated secrets below, so restore it on every run.
  run_step 60 "restore realm file" git -C "${REPO_DIR}" checkout --quiet -- local-container/keycloak/realm/galaxium-realm.json
  run_step 60 "checkout ${INFRA_TAG}" git -C "${REPO_DIR}" -c advice.detachedHead=false checkout --quiet "${INFRA_TAG}"
}

patch_realm_default() {
  local default_value="$1" new_value="$2"
  if grep -q "${default_value}" "${REALM_FILE}"; then
    sed -i.bak "s|${default_value}|${new_value}|g" "${REALM_FILE}"
    rm -f "${REALM_FILE}.bak"
  fi
}

prepare_deploy_env() {
  info "Deploy env file (only secrets and the project settings are set)"
  if [[ ! -f "${DEPLOY_ENV}" ]]; then
    cp "${CE_DIR}/deploy.env.oauth2.template" "${DEPLOY_ENV}"
    set_var "${DEPLOY_ENV}" KEYCLOAK_ADMIN_PASSWORD "$(generate_secret 16)"
    set_var "${DEPLOY_ENV}" OIDC_CLIENT_SECRET "$(generate_secret 32)"
    set_var "${DEPLOY_ENV}" FLASK_SECRET_KEY "$(generate_secret 32)"
    set_var "${DEPLOY_ENV}" GALAXIUM_DEMO_USER_PASSWORD "$(generate_secret 16)"
  fi
  set_var "${DEPLOY_ENV}" IBM_CLOUD_REGION "${IBM_CLOUD_REGION}"
  set_var "${DEPLOY_ENV}" IBM_CLOUD_RESOURCE_GROUP "${IBM_CLOUD_RESOURCE_GROUP}"
  set_var "${DEPLOY_ENV}" CE_PROJECT_NAME "${CE_PROJECT_NAME}"
  chmod 600 "${DEPLOY_ENV}"

  # Code Engine URLs are public. Replace the demo secrets from the realm file with
  # the generated ones before the realm is imported into Keycloak.
  # shellcheck disable=SC1090
  source "${DEPLOY_ENV}"
  patch_realm_default "web-app-proxy-secret" "${OIDC_CLIENT_SECRET}"
  patch_realm_default "demo-user-password" "${GALAXIUM_DEMO_USER_PASSWORD}"
  patch_realm_default "booking-api-secret" "$(generate_secret 32)"
  echo "Deploy env file: ${DEPLOY_ENV}"
}

write_endpoints_file() {
  info "Read the Code Engine URLs"
  # shellcheck disable=SC1090
  source "${DEPLOY_ENV}"
  ce_login_and_select_project
  STEP_OUT=/dev/null run_step 90 "select Code Engine project ${CE_PROJECT_NAME}" ibmcloud ce project select --name "${CE_PROJECT_NAME}"

  local keycloak_url mcp_url tmp
  tmp="$(mktemp)"
  STEP_OUT="${tmp}" run_step 90 "read Keycloak URL" ibmcloud ce application get --name "${KEYCLOAK_APP_NAME:-galaxium-keycloak}" --output url
  keycloak_url="$(tr -d '\r\n' < "${tmp}")"
  STEP_OUT="${tmp}" run_step 90 "read MCP server URL" ibmcloud ce application get --name "${MCP_APP_NAME:-galaxium-booking-mcp}" --output url
  mcp_url="$(tr -d '\r\n' < "${tmp}")"
  rm -f "${tmp}"
  [[ -n "${keycloak_url}" && -n "${mcp_url}" ]] || fail "could not read the Code Engine application URLs."

  cat > "${ENDPOINTS_FILE}" <<EOF
GALAXIUM_KEYCLOAK_URL=${keycloak_url}
GALAXIUM_TOKEN_URL=${keycloak_url}/realms/${KEYCLOAK_REALM:-galaxium}/protocol/openid-connect/token
GALAXIUM_MCP_BASE_URL=${mcp_url}
GALAXIUM_MCP_URL=${mcp_url}/mcp
GALAXIUM_OIDC_CLIENT_ID=${OIDC_CLIENT_ID:-web-app-proxy}
GALAXIUM_OIDC_CLIENT_SECRET=${OIDC_CLIENT_SECRET}
EOF
  chmod 600 "${ENDPOINTS_FILE}"
  echo "Endpoints file: ${ENDPOINTS_FILE}"
  sed -e 's|^\(GALAXIUM_OIDC_CLIENT_SECRET\)=.*|\1=<hidden>|' "${ENDPOINTS_FILE}"
}

# ── Main ───────────────────────────────────────────────────────────────────────
check_prerequisites

if [[ "${ACTION}" == "endpoints" ]]; then
  [[ -f "${DEPLOY_ENV}" ]] || fail "run 'deploy' first, ${DEPLOY_ENV} does not exist."
  write_endpoints_file
  exit 0
fi

clone_infrastructure_repo
prepare_deploy_env

if [[ "${ACTION}" == "prepare" ]]; then
  info "Prepare finished. Run the script without arguments to deploy."
  exit 0
fi

ce_login_and_select_project
info "Deploy to IBM Code Engine (several minutes, Keycloak import included)"
run_step 1800 "deploy-stack-oauth2.sh (Keycloak, MCP server, APIs, web UIs)" bash "${CE_DIR}/deploy-stack-oauth2.sh"

write_endpoints_file
info "Done. Next: bash infrastructure/verify_code_engine_oauth2.sh"
