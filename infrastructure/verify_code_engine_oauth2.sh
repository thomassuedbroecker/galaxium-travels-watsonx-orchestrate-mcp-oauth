#!/usr/bin/env bash
# Verify the OAuth2 protected Galaxium MCP server on IBM Code Engine.
# Reads infrastructure/galaxium-endpoints.env written by deploy_code_engine_oauth2.sh.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENDPOINTS_FILE="${SCRIPT_DIR}/galaxium-endpoints.env"
MCP_HEADERS=(-H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -H 'MCP-Protocol-Version: 2025-11-25')

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC} $*"; }
fail() { echo -e "${RED}FAIL${NC} $*" >&2; exit 1; }

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../bash-lib/step_progress.sh"
TMP_OUT="$(mktemp)"
headers_file="$(mktemp)"
trap 'rm -f "${headers_file}" "${TMP_OUT}"' EXIT

command -v curl >/dev/null 2>&1 || fail "curl is not installed."
command -v jq >/dev/null 2>&1 || fail "jq is not installed."
[[ -f "${ENDPOINTS_FILE}" ]] || fail "missing ${ENDPOINTS_FILE}. Run deploy_code_engine_oauth2.sh (new stack) or import_existing_deployment.sh (existing stack) first."
set -a; source "${ENDPOINTS_FILE}"; set +a

# 1. Unauthenticated access must be rejected (first call may wake a scaled-to-zero app)
STEP_OUT="${TMP_OUT}" run_step 100 "1/5 call MCP without token (may wake Code Engine)" curl -s -o /dev/null -w '%{http_code}' --max-time 90 -X POST "${GALAXIUM_MCP_URL}" "${MCP_HEADERS[@]}" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' || true
status="$(cat "${TMP_OUT}")"
[[ "${status}" == "401" ]] && pass "no token -> 401" || fail "no token -> ${status} (expected 401)"

# 2. OAuth metadata must not advertise the implicit flow
STEP_OUT="${TMP_OUT}" run_step 70 "2/5 read OAuth metadata" curl -fsS --max-time 60 "${GALAXIUM_MCP_BASE_URL}/.well-known/oauth-authorization-server" || fail "OAuth metadata not reachable"
metadata="$(cat "${TMP_OUT}")"
if echo "${metadata}" | jq -e '.grant_types_supported | index("implicit") | not' >/dev/null; then
  pass "metadata does not list the implicit grant"
else
  fail "metadata lists the implicit grant"
fi

# 3. client_credentials token from Keycloak
STEP_OUT="${TMP_OUT}" run_step 70 "3/5 request client_credentials token" curl -fsS --max-time 60 -X POST "${GALAXIUM_TOKEN_URL}" \
  -u "${GALAXIUM_OIDC_CLIENT_ID}:${GALAXIUM_OIDC_CLIENT_SECRET}" \
  -d grant_type=client_credentials || fail "token request failed"
ACCESS_TOKEN="$(jq -r .access_token < "${TMP_OUT}")"
[[ -n "${ACCESS_TOKEN}" && "${ACCESS_TOKEN}" != "null" ]] && pass "client_credentials token issued" || fail "no access token"

# 4. initialize with the token
STEP_OUT="${TMP_OUT}" run_step 70 "4/5 initialize with token" curl -s -o /dev/null -D "${headers_file}" -w '%{http_code}' --max-time 60 -X POST "${GALAXIUM_MCP_URL}" \
  "${MCP_HEADERS[@]}" -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"verify","version":"1.0.0"}}}' || true
status="$(cat "${TMP_OUT}")"
[[ "${status}" == "200" ]] && pass "initialize with token -> 200" || fail "initialize -> ${status} (expected 200)"
SESSION_ID="$(grep -i '^mcp-session-id:' "${headers_file}" | awk '{print $2}' | tr -d '\r')"
[[ -n "${SESSION_ID}" ]] || fail "no mcp-session-id header in the initialize response"

# 5. tools/list returns the booking tools
STEP_OUT="${TMP_OUT}" run_step 70 "5/5 list tools" curl -sS --max-time 60 -X POST "${GALAXIUM_MCP_URL}" "${MCP_HEADERS[@]}" \
  -H "MCP-Session-Id: ${SESSION_ID}" -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' || fail "tools/list failed"
tools="$(cat "${TMP_OUT}")"
for tool in list_flights book_flight get_bookings cancel_booking register_user get_user_id; do
  echo "${tools}" | grep -q "\"${tool}\"" || fail "tool '${tool}' missing in tools/list"
done
pass "tools/list returns the 6 booking tools"
