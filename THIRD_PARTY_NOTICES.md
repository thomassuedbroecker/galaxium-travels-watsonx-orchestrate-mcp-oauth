# Third-Party Notices

| Material | Source | License | Use here |
|---|---|---|---|
| `ibm-watsonx-orchestrate` | PyPI | MIT | Installed at runtime into `.venv` |
| galaxium-travels-infrastructure-tsuedbro | [GitHub](https://github.com/thomassuedbroecker/galaxium-travels-infrastructure-tsuedbro) | Apache-2.0 | Cloned at runtime, not redistributed |
| Keycloak | `quay.io/keycloak/keycloak:26.0` | Apache-2.0 | Deployed by the infrastructure repository |
| `jq` | [Homebrew formula](https://formulae.brew.sh/formula/jq) | MIT | Installed by the user, called by the scripts, not redistributed |
| `git` | [Homebrew formula](https://formulae.brew.sh/formula/git) | GPL-2.0-only and others (see formula) | Installed by the user, called by the scripts, not redistributed |
| `ibmcloud` CLI, `code-engine` plugin, `curl`, `python3` | Vendor / OS distribution | See the vendor terms | Installed by the user, called by the scripts, not redistributed |

The scripts and guides in this repository are derived from the guide structure of the original repository (MIT, see [LICENSE](./LICENSE)).
The scripts added here (`bash-lib/step_progress.sh`, `infrastructure/path-a-deploy/`, `infrastructure/path-b-existing/`, `watsonx-orchestrate-adk/wxo_*.sh`) are original work under the same MIT license.
