#!/usr/bin/env bash
# Install the watsonx Orchestrate ADK into watsonx-orchestrate-adk/.venv.
# Only the CLI is installed. The remote watsonx Orchestrate instance is used,
# no Developer Edition containers are started.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck disable=SC1091
source ../bash-lib/step_progress.sh

ADK_VERSION="${ADK_VERSION:-2.18.2}"

if command -v python3.13 >/dev/null 2>&1; then
  PYTHON=python3.13
else
  PYTHON=python3
fi
command -v "${PYTHON}" >/dev/null 2>&1 || { echo "ERROR: Python 3 is not installed." >&2; exit 1; }

echo "Using $(${PYTHON} --version) to create .venv"
[[ -d .venv ]] || run_step 120 "create .venv" "${PYTHON}" -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
run_step 180 "upgrade pip" python -m pip install --quiet --upgrade pip
run_step 600 "install ibm-watsonx-orchestrate==${ADK_VERSION}" python -m pip install --quiet "ibm-watsonx-orchestrate==${ADK_VERSION}"
orchestrate --version
