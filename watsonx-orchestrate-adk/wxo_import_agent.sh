#!/usr/bin/env bash
# Import the Galaxium booking example agent into the remote watsonx Orchestrate instance.
# Run after wxo_add_oauth2_mcp_server.sh:
#   bash watsonx-orchestrate-adk/wxo_import_agent.sh
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/wxo_env.sh"

wxo_info "Models available in this instance (the agent llm must be one of them)"
wxo_run 90 "models list" orchestrate models list || true

wxo_info "Import the agent"
wxo_run 180 "agents import" orchestrate agents import --file "${WXO_ADK_DIR}/agents/agent_galaxium_booking_oauth2_test.yaml"
wxo_run 60 "agents list" orchestrate agents list

cat <<EOF

Test the agent in the watsonx Orchestrate web UI (draft version):
  Chat -> select 'galaxium_booking_oauth2_test_agent' -> ask: Which flights are available?

Optional, release the draft as a new live version:
  orchestrate agents deploy --name galaxium_booking_oauth2_test_agent
EOF
