#!/usr/bin/env bash
# Create infrastructure/galaxium-endpoints.env for an ALREADY DEPLOYED Galaxium stack
# (deployed by anyone, from any repository). The infrastructure repository is NOT cloned.
#
# Usage:
#   bash infrastructure/path-b-existing/import_existing_deployment.sh --links <deployment-links.env> [--deploy-env <deploy.env.oauth2>]
#   bash infrastructure/path-b-existing/import_existing_deployment.sh --code-engine [--deploy-env <deploy.env.oauth2>]
#
#   --links <file>       URLs from the deployment-links.env written by export-deployment.sh --oauth2
#   --code-engine        URLs read directly from the IBM Code Engine project (needs ibmcloud)
#   --deploy-env <file>  deploy.env.oauth2 copied from the repository that did the deployment.
#                        Used for OIDC_CLIENT_SECRET, OIDC_CLIENT_ID, KEYCLOAK_REALM and, with
#                        --code-engine, IBM_CLOUD_*, CE_PROJECT_NAME and the *_APP_NAME values.
#
# Client secret order: GALAXIUM_OIDC_CLIENT_SECRET, then OIDC_CLIENT_SECRET from --deploy-env,
# otherwise it is requested (hidden input). It is never part of the export.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENDPOINTS_FILE="${INFRA_DIR}/galaxium-endpoints.env"
MODE=""
LINKS_FILE=""
DEPLOY_ENV_FILE=""

fail() { echo "ERROR: $*" >&2; exit 1; }
# shellcheck disable=SC1091
source "${INFRA_DIR}/../bash-lib/step_progress.sh"
usage() { fail "usage: $0 (--links <deployment-links.env> | --code-engine) [--deploy-env <deploy.env.oauth2>]"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --links) MODE="links"; LINKS_FILE="${2:-}"; shift 2 || usage ;;
    --code-engine) MODE="code-engine"; shift ;;
    --deploy-env) DEPLOY_ENV_FILE="${2:-}"; shift 2 || usage ;;
    *) usage ;;
  esac
done
[[ -n "${MODE}" ]] || usage

if [[ -f "${INFRA_DIR}/.env" ]]; then
  set -a; source "${INFRA_DIR}/.env"; set +a
fi
if [[ -n "${DEPLOY_ENV_FILE}" ]]; then
  [[ -f "${DEPLOY_ENV_FILE}" ]] || fail "missing deploy env file: ${DEPLOY_ENV_FILE}"
  # shellcheck disable=SC1090
  set -a; source "${DEPLOY_ENV_FILE}"; set +a
fi

case "${MODE}" in
  links)
    [[ -f "${LINKS_FILE}" ]] || fail "missing links file: ${LINKS_FILE:-<none>}"
    # shellcheck disable=SC1090
    set -a; source "${LINKS_FILE}"; set +a
    keycloak_url="${KEYCLOAK_URL:-}"
    mcp_url="${MCP_BASE_URL:-}"
    ;;
  code-engine)
    command -v ibmcloud >/dev/null 2>&1 || fail "ibmcloud CLI is not installed."
    ibmcloud plugin show code-engine >/dev/null 2>&1 || fail "install the plugin: ibmcloud plugin install code-engine"
    [[ -n "${IBM_CLOUD_API_KEY:-}" && "${IBM_CLOUD_API_KEY}" != "<YOUR_IBM_CLOUD_API_KEY>" ]] \
      || fail "set IBM_CLOUD_API_KEY in ${INFRA_DIR}/.env (copy .env_template first)."
    STEP_OUT=/dev/null run_step 120 "ibmcloud login" ibmcloud login --apikey "${IBM_CLOUD_API_KEY}" \
      -r "${IBM_CLOUD_REGION:-us-south}" -g "${IBM_CLOUD_RESOURCE_GROUP:-default}" -q
    STEP_OUT=/dev/null run_step 90 "select Code Engine project" ibmcloud ce project select --name "${CE_PROJECT_NAME:-galaxium-travels-oauth2}"
    tmp="$(mktemp)"
    STEP_OUT="${tmp}" run_step 90 "read Keycloak URL" ibmcloud ce application get --name "${KEYCLOAK_APP_NAME:-galaxium-keycloak}" --output url
    keycloak_url="$(tr -d '\r\n' < "${tmp}")"
    STEP_OUT="${tmp}" run_step 90 "read MCP server URL" ibmcloud ce application get --name "${MCP_APP_NAME:-galaxium-booking-mcp}" --output url
    mcp_url="$(tr -d '\r\n' < "${tmp}")"
    rm -f "${tmp}"
    ;;
esac

[[ -n "${keycloak_url}" && -n "${mcp_url}" ]] || fail "could not determine the Keycloak and MCP URLs."
[[ "${keycloak_url}${mcp_url}" != *"<"* ]] || fail "replace the <placeholders> in the links file with real URLs."
keycloak_url="${keycloak_url%/}"
mcp_url="${mcp_url%/}"

client_secret="${GALAXIUM_OIDC_CLIENT_SECRET:-${OIDC_CLIENT_SECRET:-}}"
if [[ -z "${client_secret}" ]]; then
  read -r -s -p "OIDC client secret (OIDC_CLIENT_SECRET of the deployment): " client_secret || true
  echo
fi
[[ -n "${client_secret}" ]] || fail "the OIDC client secret is required."

cat > "${ENDPOINTS_FILE}" <<EOF
GALAXIUM_KEYCLOAK_URL=${keycloak_url}
GALAXIUM_TOKEN_URL=${keycloak_url}/realms/${KEYCLOAK_REALM:-galaxium}/protocol/openid-connect/token
GALAXIUM_MCP_BASE_URL=${mcp_url}
GALAXIUM_MCP_URL=${mcp_url}/mcp
GALAXIUM_OIDC_CLIENT_ID=${OIDC_CLIENT_ID:-web-app-proxy}
GALAXIUM_OIDC_CLIENT_SECRET=${client_secret}
EOF
chmod 600 "${ENDPOINTS_FILE}"

echo "Endpoints file: ${ENDPOINTS_FILE}"
sed -e 's|^\(GALAXIUM_OIDC_CLIENT_SECRET\)=.*|\1=<hidden>|' "${ENDPOINTS_FILE}"
echo "Next: bash infrastructure/verify_code_engine_oauth2.sh"
