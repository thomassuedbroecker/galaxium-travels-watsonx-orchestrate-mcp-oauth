# 1. Set Up The Galaxium Travels Infrastructure On IBM Code Engine

This guide covers two paths:

- **Path A — Deploy from scratch** (§1.1 – §1.7): clone the infrastructure repository first, then
  provision Keycloak, the Booking MCP server, the Booking REST API, the HR API and both web UIs
  on IBM Code Engine with one script.
- **Path B — Already deployed from another repository** (§1.8): the infrastructure repository is
  **not** cloned here. You copy the deployer's `deploy.env.oauth2` and the `deployment-links.env`
  export, and `import_existing_deployment.sh` writes `galaxium-endpoints.env`.

The runnable stack comes from
[galaxium-travels-infrastructure-tsuedbro](https://github.com/thomassuedbroecker/galaxium-travels-infrastructure-tsuedbro),
release `v6.2.3` (Code Engine Path B, OAuth2).

> **Cost notice:** Deploying the stack creates billable resources on IBM Cloud Code Engine.
> Charges apply for build time (one-time, Path A only), running application instances (vCPU-hours + GB-hours),
> and incoming HTTP requests. The MCP server, APIs and web UIs scale to zero when idle, but **Keycloak is kept running
> (`min-scale 1`)**, so there is a continuous charge between test sessions until you tear the stack down.
> Run the teardown script (§1.6) when you are done. For a full breakdown see the
> [Cost Estimate section in the README](./README.md#cost-estimate).

## 1.1 Prerequisites

| Tool / account | Notes |
|---|---|
| IBM Cloud account | Needs permission to create a Code Engine project |
| IBM Cloud API key | [Create one](https://cloud.ibm.com/iam/apikeys) |
| `ibmcloud` CLI | `curl -fsSL https://clis.cloud.ibm.com/install/osx \| sh` (Linux: `.../install/linux`) |
| Code Engine plugin | `ibmcloud plugin install code-engine` |
| `git`, `curl`, `jq`, `python3` | `brew install jq` on macOS |
| `kubectl` (optional) | Only for `infrastructure/inspect_code_engine.sh` (pods and logs) |

No container runtime is needed. Code Engine builds the images from source
(`DEPLOY_ARTIFACT_MODE=source_build`, the default of the infrastructure repository).

## 1.2 Clone The Infrastructure Repository (First Step Of Path A)

This guide is written for release `v6.2.3` of the infrastructure repository.

From the root of this repository:

```sh
cd infrastructure
git clone https://github.com/thomassuedbroecker/galaxium-travels-infrastructure-tsuedbro.git
cd galaxium-travels-infrastructure-tsuedbro
git checkout v6.2.3
cd ../..
```

If you already cloned it earlier, just enter the directory and check out the release:

```sh
cd infrastructure/galaxium-travels-infrastructure-tsuedbro
git fetch --tags
git checkout v6.2.3
cd ../..
```

The clone is git-ignored. The deploy script (§1.4) performs the same clone and checkout if the
directory is missing, so this step is safe to repeat and lets you inspect the upstream scripts first.

## 1.3 Configure (One Value)

Create the infrastructure settings:

```sh
cp infrastructure/.env_template infrastructure/.env
```

Edit `infrastructure/.env` and set **only** `IBM_CLOUD_API_KEY`.
Region (`us-south`), resource group (`default`) and project name (`galaxium-travels-oauth2`) have defaults.

## 1.4 Deploy

```sh
bash infrastructure/path-a-deploy/deploy_code_engine_oauth2.sh
```

What the script does:

1. Uses the clone from §1.2 (clones it if missing) and checks out `v6.2.3`.
2. Creates `deploy.env.oauth2` from the template and **generates** the Keycloak admin password, the OAuth2 client secret, the Flask secret and the demo user password.
3. Replaces the demo secrets in the cloned Keycloak realm file (client secret, demo user password, `booking-api` secret) with generated values, because the realm is imported into Keycloak at deployment time and the client secret must match `OIDC_CLIENT_SECRET`.
4. Runs the upstream `deploy-stack-oauth2.sh` (steps `00 → 06`): project, secrets, Keycloak, services, Keycloak client sync, summary.
5. Reads the public HTTPS URLs and writes `infrastructure/galaxium-endpoints.env`.

The first deployment takes several minutes. Add `CE_DEBUG=1` in front of the command to see the full `ibmcloud` output.

> **Why no LAN IP configuration?** In the local setup Keycloak and the MCP server must share one
> host name (the `iss` claim must match). On Code Engine every application gets a public HTTPS
> URL and the upstream scripts derive `OIDC_ISSUER`, the JWKS URL and the token URL from the real
> Keycloak URL. Nothing has to be configured by hand.

## 1.5 Result: `galaxium-endpoints.env`

| Variable | Used for |
|---|---|
| `GALAXIUM_KEYCLOAK_URL` | Keycloak root URL (token `iss` check, cold-start warm-up) |
| `GALAXIUM_TOKEN_URL` | `--token-url` of the watsonx Orchestrate connection |
| `GALAXIUM_MCP_BASE_URL` | `--url` of the connection (server root) |
| `GALAXIUM_MCP_URL` | `--url` of the toolkit import (`.../mcp`) |
| `GALAXIUM_OIDC_CLIENT_ID` | `web-app-proxy` |
| `GALAXIUM_OIDC_CLIENT_SECRET` | generated, never committed |

If a Code Engine URL changes, rewrite the file with
`bash infrastructure/path-a-deploy/deploy_code_engine_oauth2.sh endpoints`.

## 1.6 Other Actions

```sh
bash infrastructure/path-a-deploy/deploy_code_engine_oauth2.sh prepare     # clone + generate env file only
bash infrastructure/path-a-deploy/deploy_code_engine_oauth2.sh endpoints   # re-read the URLs
```

Export the live deployment links and configuration (no secret values) — added in `v6.2.1`, improved in `v6.2.3`:

```sh
# from inside the cloned infrastructure directory
bash infrastructure/galaxium-travels-infrastructure-tsuedbro/deployment/ibm-code-engine/export-deployment.sh --oauth2
```

Output is written to `deployment/ibm-code-engine/generated/exports/<project>-oauth2-<timestamp>/`:

| File | Content |
|---|---|
| `deployment-links.md` | Human-readable public URLs and settings |
| `deployment-links.env` | Machine-readable `KEY=VALUE` links |
| `configmaps/*.json` | Live Code Engine configmaps |
| `applications/*.json` | Live Code Engine application definitions |

Secret values are never exported — only secret names are listed.

Teardown (keeps the Code Engine project, deletes applications, configmaps and secrets):

```sh
bash infrastructure/galaxium-travels-infrastructure-tsuedbro/deployment/ibm-code-engine/teardown-stack-oauth2.sh
```

## 1.7 Common Problems

| Symptom | Cause | Fix |
|---|---|---|
| `IBM Cloud Code Engine plugin missing` | Plugin not installed | `ibmcloud plugin install code-engine` |
| `set IBM_CLOUD_API_KEY` | `.env` not filled in | Edit `infrastructure/.env` |
| Deployment stops in `05-sync-keycloak-client.sh` | Keycloak still starting | Re-run the script, the steps are idempotent |
| Re-deploy after changing secrets has no effect | `deploy.env.oauth2` already exists | Delete it (and run teardown) to generate new secrets |

Reference: `deployment/ibm-code-engine/DEPLOY-PATH-B-OAUTH2.md` in the infrastructure repository.

## 1.8 Already Deployed — Use A Deployment From Another Repository

If the stack is already running (deployed by someone else, or from another repository), skip
§1.2 – §1.4 and do **not** clone the infrastructure repository here. You only need
`infrastructure/galaxium-endpoints.env`, which
[`import_existing_deployment.sh`](./infrastructure/path-b-existing/import_existing_deployment.sh) creates.

### What you need from the other repository

Copy these two items from the repository (or person) that did the deployment:

| # | What | Where it comes from | Contains secrets |
|---|---|---|---|
| 1 | `deploy.env.oauth2` | `deployment/ibm-code-engine/deploy.env.oauth2` (git-ignored there) | **Yes** (`OIDC_CLIENT_SECRET`, admin password, ...) |
| 2 | `deployment-links.env` | Output of `export-deployment.sh --oauth2`, in `deployment/ibm-code-engine/generated/exports/<project>-oauth2-<timestamp>/` | No |

Why both: the export has the public URLs but never a secret. `deploy.env.oauth2` has the client
secret (and the client ID, realm and app names) but not the URLs. Together they contain everything
the later guides need.

Store both copied files in the `infrastructure/` folder of this repository. Both are git-ignored:

- `infrastructure/deploy.env.oauth2`
- `infrastructure/deployment-links.env`

Only `OIDC_CLIENT_SECRET` (and optionally `OIDC_CLIENT_ID`,
`KEYCLOAK_REALM`) is read from `deploy.env.oauth2`. Do not paste its content into chats or commits.

If the other repository has no export yet, create it there (needs `ibmcloud` login or
`IBM_CLOUD_API_KEY` in `deploy.env.oauth2`):

```sh
cd <other-repo>/deployment/ibm-code-engine
bash export-deployment.sh --oauth2
```

### Create `galaxium-endpoints.env`

```sh
bash infrastructure/path-b-existing/import_existing_deployment.sh \
  --links infrastructure/deployment-links.env \
  --deploy-env infrastructure/deploy.env.oauth2
```

`--links` accepts any path. `infrastructure/deployment-links.env` is the recommended location because
`inspect_code_engine.sh` also reads it. This route needs **no** `IBM_CLOUD_API_KEY`.

The client secret is taken in this order: `GALAXIUM_OIDC_CLIENT_SECRET`, then
`OIDC_CLIENT_SECRET` from `--deploy-env`, otherwise the script asks for it (hidden input).

`deployment-links.env` needs only two keys, see
[`infrastructure/path-b-existing/deployment-links.env_template`](./infrastructure/path-b-existing/deployment-links.env_template):

```text
KEYCLOAK_URL=https://<keycloak-app>...codeengine.appdomain.cloud
MCP_BASE_URL=https://<mcp-app>...codeengine.appdomain.cloud
```

### Alternative — read the URLs from the Code Engine project

No export file needed. Needs `ibmcloud` with the code-engine plugin and **an `IBM_CLOUD_API_KEY`** that can access the project. `IBM_CLOUD_API_KEY`,
`IBM_CLOUD_REGION`, `IBM_CLOUD_RESOURCE_GROUP`, `CE_PROJECT_NAME`, `KEYCLOAK_APP_NAME` and
`MCP_APP_NAME` come from `--deploy-env` or from `infrastructure/.env`
(defaults: `us-south`, `default`, `galaxium-travels-oauth2`, `galaxium-keycloak`, `galaxium-booking-mcp`).

```sh
bash infrastructure/path-b-existing/import_existing_deployment.sh --code-engine --deploy-env infrastructure/deploy.env.oauth2
```

Once `galaxium-endpoints.env` exists, continue with guide
[2 — Verify The OAuth2 MCP Server](./2-galaxium_oauth2_mcp_verification.md).

## [Home](./README.md)
