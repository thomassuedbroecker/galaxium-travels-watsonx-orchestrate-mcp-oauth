# 3. Set Up The `watsonx Orchestrate` ADK (Remote Instance)

This guide installs the ADK (the `orchestrate` CLI) and connects it to your **remote**
watsonx Orchestrate instance. The **Developer Edition is not used**: there is no Lima VM,
no container runtime, no entitlement key and no local `watsonx.ai` setup.

> **Cost notice:** This guide connects to an **existing** watsonx Orchestrate instance — it does not provision a new one.
> No additional instance charges are created by following these steps.
> If you are on a Trial plan, no payment is required; see the
> [Cost Estimate section in the README](./README.md#cost-estimate) for plan options.

## 3.1 Prerequisites

| Requirement | Notes |
|---|---|
| watsonx Orchestrate instance | [Trial](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=orchestrate-accessing-watsonx-trial-version) or paid plan on IBM Cloud |
| IBM Cloud API key | Can be the same key as in guide 1 |
| Python `3.13` (or `3.11`/`3.12`) | `python3.13` is used if found, otherwise `python3` |

## 3.2 Get The Service Instance URL

In the watsonx Orchestrate web UI: profile icon → **Settings** → **API details** →
**Service instance URL**. Direct link for `us-south`:
<https://us-south.watson-orchestrate.cloud.ibm.com/settings?tab=api-details>
(other regions: replace `us-south` with your region).

It looks like
`https://api.<region>.watson-orchestrate.cloud.ibm.com/instances/<INSTANCE_ID>`.
Its host must contain `watson-orchestrate`. Copy the value from this page, not from the browser address bar.

## 3.3 Create The `.env` File (Two Values)

```sh
cp watsonx-orchestrate-adk/.env_template watsonx-orchestrate-adk/.env
```

Set `WXO_API_KEY` and `WXO_URL` in `watsonx-orchestrate-adk/.env`. Nothing else is required.

> The file lives in `watsonx-orchestrate-adk/`, **not** in the repository root. The scripts load
> it from there automatically. When you run `orchestrate` commands by hand, you must load it
> yourself (§3.5), otherwise `${WXO_URL}` and `${WXO_API_KEY}` are empty.
>
> `infrastructure/.env` is a different file (IBM Cloud API key for the Code Engine deployment).

## 3.4 Install The ADK

```sh
bash watsonx-orchestrate-adk/wxo_install_adk.sh
```

This creates `watsonx-orchestrate-adk/.venv` and installs `ibm-watsonx-orchestrate==2.18.2`
(override with `ADK_VERSION=<version>`).

## 3.5 Connect To The Remote Instance

All following scripts source [`wxo_env.sh`](./watsonx-orchestrate-adk/wxo_env.sh), which activates
the venv, loads `watsonx-orchestrate-adk/.env` and runs (the environment name `galaxium-remote`
can be changed with the optional `WXO_ENV_NAME` in `.env`):

```sh
source watsonx-orchestrate-adk/.venv/bin/activate
set -a; source watsonx-orchestrate-adk/.env; set +a
orchestrate env remove --name galaxium-remote
orchestrate env add --name galaxium-remote --url "${WXO_URL}"
orchestrate env activate galaxium-remote --api-key "${WXO_API_KEY}"
```

Check it manually once. Run it from the repository root, in the same shell. The `echo` line
confirms that the values are loaded without printing the key:

```sh
source watsonx-orchestrate-adk/.venv/bin/activate
set -a; source watsonx-orchestrate-adk/.env; set +a
echo "WXO_URL=${WXO_URL:-<EMPTY>}  WXO_API_KEY length=${#WXO_API_KEY}"
orchestrate env remove --name galaxium-remote
orchestrate env add --name galaxium-remote --url "${WXO_URL}"
orchestrate env activate galaxium-remote --api-key "${WXO_API_KEY}"
orchestrate env list
orchestrate agents list
```

`WXO_URL` must show the Service instance URL and the key length must be greater than `0`.
`orchestrate env list` must mark `galaxium-remote` as `(active)`. If another environment is active
(for example `local`, the Developer Edition, which must not be used), the activation failed and
`agents list` shows the agents of that other environment. Fix the error printed by `env activate`
first. The scripts check this and stop.
Open a new terminal? Run the `source` lines again, shell variables are not kept.

> The activation token expires after some time. Every script activates the environment again,
> so you never have to do this by hand.

## 3.6 Common Problems

| Symptom | Cause | Fix |
|---|---|---|
| `Environment 'galaxium-remote' is misconfigured` on `env activate` | `watsonx-orchestrate-adk/.env` was not loaded, so `--url` was empty | Run `set -a; source watsonx-orchestrate-adk/.env; set +a`, check with the `echo` line, then `env remove` and `env add` again |
| `Failed to authenticate to provided instance ... Reason: 'Not Found'` | `WXO_URL` points to another service, for example a host with `assistant-builder.watson.cloud.ibm.com` | Use the **Service instance URL** from the watsonx Orchestrate UI (Settings → API details). Its host contains `watson-orchestrate.cloud.ibm.com` |
| `env activate` returns `401` | Wrong API key or the key belongs to another account | Create a key in the account that owns the instance |
| `env add` rejects the URL | Console URL used instead of the API URL | Use the **Service instance URL** (contains `/instances/`) |
| `orchestrate: command not found` | venv not active | `source watsonx-orchestrate-adk/.venv/bin/activate` |

References:

- <https://developer.watson-orchestrate.ibm.com/getting_started/environments>
- <https://developer.watson-orchestrate.ibm.com/>

## [Home](./README.md)
