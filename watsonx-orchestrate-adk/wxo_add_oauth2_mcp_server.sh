#!/usr/bin/env bash
# Register the OAuth2 protected Galaxium MCP server (IBM Code Engine) in the remote
# watsonx Orchestrate instance: connection (client_credentials) + remote MCP toolkit.
#
# Prerequisites: infrastructure/path-a-deploy/deploy_code_engine_oauth2.sh (or path-b-existing/import_existing_deployment.sh) has run, and
# watsonx-orchestrate-adk/.env exists. Run from any folder:
#   bash watsonx-orchestrate-adk/wxo_add_oauth2_mcp_server.sh
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/wxo_env.sh"

[[ -f "${GALAXIUM_ENDPOINTS_FILE}" ]] \
  || wxo_fail "missing ${GALAXIUM_ENDPOINTS_FILE}. Run infrastructure/path-a-deploy/deploy_code_engine_oauth2.sh or infrastructure/path-b-existing/import_existing_deployment.sh first."
set -a; source "${GALAXIUM_ENDPOINTS_FILE}"; set +a

APP_ID="galaxium_mcp_oauth2_server"
TOOLKIT_NAME="galaxium_travels_booking_mcp_oauth2"
# MCP_REMOTE_BASE_SERVER_URL: server root for the connection. MCP_REMOTE_SERVER_URL: full MCP endpoint.
TOOLS="list_flights,book_flight,get_bookings,cancel_booking,register_user,get_user_id"

wxo_info "OAuth2 MCP config"
echo "APP_ID:       ${APP_ID}"
echo "TOKEN_URL:    ${GALAXIUM_TOKEN_URL}"
echo "MCP_URL:      ${GALAXIUM_MCP_URL}"
echo "TOOLKIT_NAME: ${TOOLKIT_NAME}"

# The toolkit import calls tools/list on the live server. Wake up Code Engine first
# (the MCP server scales to zero, Keycloak stays up) so the import does not run into a cold-start timeout.
wxo_info "Warm up the Code Engine applications"
wxo_run 100 "warm up Keycloak" curl -s -o /dev/null --max-time 90 "${GALAXIUM_KEYCLOAK_URL}/realms/galaxium/.well-known/openid-configuration" || true
wxo_run 100 "warm up MCP server" curl -s -o /dev/null --max-time 90 "${GALAXIUM_MCP_BASE_URL}/.well-known/oauth-protected-resource" || true

wxo_info "1/3 Create the connection"
wxo_run 90 "connections remove ${APP_ID} (ignored if it does not exist)" orchestrate connections remove --app-id "${APP_ID}" || true
wxo_run 90 "connections add ${APP_ID}" orchestrate connections add --app-id "${APP_ID}"

# watsonx Orchestrate does NOT support OAuth (Implicit) for Remote MCP Toolkits (see https://developer.watson-orchestrate.ibm.com/connections/overview).
# Use oauth_auth_client_credentials_flow (machine-to-machine).
wxo_info "2/3 Configure and set the credentials (draft and live)"
for environment in draft live; do
  wxo_run 90 "connections configure (${environment})" orchestrate connections configure \
    --app-id "${APP_ID}" \
    --env "${environment}" \
    --kind oauth_auth_client_credentials_flow \
    --type team \
    --url "${GALAXIUM_MCP_BASE_URL}"
  wxo_run 90 "connections set-credentials (${environment})" orchestrate connections set-credentials \
    --app-id "${APP_ID}" \
    --env "${environment}" \
    --client-id "${GALAXIUM_OIDC_CLIENT_ID}" \
    --client-secret "${GALAXIUM_OIDC_CLIENT_SECRET}" \
    --token-url "${GALAXIUM_TOKEN_URL}"
done

wxo_info "3/3 Import the MCP toolkit (calls tools/list on the MCP server, can take a minute)"
wxo_run 180 "toolkits remove ${TOOLKIT_NAME} (ignored if it does not exist)" orchestrate toolkits remove --name "${TOOLKIT_NAME}" || true
wxo_run 240 "toolkits add ${TOOLKIT_NAME}" orchestrate toolkits add \
  --kind mcp \
  --name "${TOOLKIT_NAME}" \
  --description "Galaxium Travels Booking MCP imported through OAuth2 client credentials." \
  --transport streamable_http \
  --tools "${TOOLS}" \
  --url "${GALAXIUM_MCP_URL}" \
  --app-id "${APP_ID}"

wxo_info "Done. Next: bash watsonx-orchestrate-adk/wxo_import_agent.sh"
wxo_run 60 "toolkits list" orchestrate toolkits list
