#!/usr/bin/env bash
# Remove what wxo_add_oauth2_mcp_server.sh and wxo_import_agent.sh added to the remote
# watsonx Orchestrate instance: agent, MCP toolkit, connection.
#   bash watsonx-orchestrate-adk/wxo_cleanup.sh              # asks for confirmation
#   bash watsonx-orchestrate-adk/wxo_cleanup.sh --yes        # no confirmation
# Only the three Galaxium resources are removed. Missing resources are ignored.
# The remote access configuration (.env, CLI environment) is kept.
set -euo pipefail

AUTO_YES=false
for arg in "$@"; do
  case "${arg}" in
    --yes|-y) AUTO_YES=true ;;
    *) echo "Unknown option: ${arg}" >&2; exit 1 ;;
  esac
done

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/wxo_env.sh"

AGENT_NAME="galaxium_booking_oauth2_test_agent"
TOOLKIT_NAME="galaxium_travels_booking_mcp_oauth2"
APP_ID="galaxium_mcp_oauth2_server"

wxo_info "Resources to remove from '${WXO_ENV_NAME}'"
echo "agent:      ${AGENT_NAME}"
echo "toolkit:    ${TOOLKIT_NAME}"
echo "connection: ${APP_ID}"

if [[ "${AUTO_YES}" != true ]]; then
  read -r -p "Remove these resources from the remote instance? (y/N) " answer
  [[ "${answer}" =~ ^[yY]$ ]] || { echo "Aborted."; exit 0; }
fi

# Order matters: the agent uses the toolkit, the toolkit uses the connection.
wxo_info "1/3 Remove the agent"
wxo_run 120 "agents remove ${AGENT_NAME} (ignored if it does not exist)" orchestrate agents remove --name "${AGENT_NAME}" --kind native || true

wxo_info "2/3 Remove the MCP toolkit"
wxo_run 180 "toolkits remove ${TOOLKIT_NAME} (ignored if it does not exist)" orchestrate toolkits remove --name "${TOOLKIT_NAME}" || true

wxo_info "3/3 Remove the connection"
wxo_run 90 "connections remove ${APP_ID} (ignored if it does not exist)" orchestrate connections remove --app-id "${APP_ID}" || true

wxo_info "Remaining resources"
wxo_run 60 "agents list" orchestrate agents list || true
wxo_run 60 "toolkits list" orchestrate toolkits list || true
wxo_run 60 "connections list" orchestrate connections list || true

echo
echo "Done. The Code Engine deployment is not touched (remove it in the IBM Cloud console or with the ibmcloud CLI)."
