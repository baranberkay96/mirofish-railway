# MiroFish v0.1 Swarm Intelligence Engine — Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **MiroFish v0.1 Swarm Intelligence Engine** (`v0.1` = MiroFish's 0.1 line: built from `main` at `7657031`, 103 commits after the v0.1.2 release, no newer tag exists) |
| Description | Simulate many AI agents to explore how events and opinions unfold. (66 chars) |
| Category | AI/ML |
| Tags | mirofish, multi-agent, agent-simulation, swarm-intelligence, social-simulation, oasis, llm, zep |
| Icon | `https://cdn.jsdelivr.net/gh/666ghj/MiroFish@7657031ac01184afe2cb220f5ee3545573b5e843/frontend/public/icon.png` (HTTP 200, image/png, checked 2026-10-20) |
| Repo | `baranberkay96/mirofish-railway` (assumed from the `<slug>-railway` convention; not given in the task) |
| User input at deploy | **Required:** `LLM_API_KEY` (any OpenAI-compatible provider) and `ZEP_API_KEY` (Zep Cloud) on the **MiroFish** service. Everything else has a default or is generated. |

**Listing wording.** What MiroFish does (checked in the source): you upload seed documents (PDF/Markdown/text) and describe a scenario; an LLM extracts an ontology, MiroFish builds a knowledge graph in Zep Cloud, turns its entities into agent personas, runs them on simulated Twitter-like and Reddit-like platforms with CAMEL-AI's OASIS for N rounds, writes a report with a tool-using ReportAgent, and lets you chat with individual agents. The given description matches that. Upstream markets it as "Predicting Anything"; this template deliberately makes no prediction claims: the output is an LLM simulation, not a forecast.

## Base market template

| Code | Name | Stats (from `_market/mirofish.json`) | Verdict |
|---|---|---|---|
| `mirofish` | "Mirofish" | 12 projects, 11 active, created 2026-08-01, unverified | Only market template; used as the base for the variable set and the volume path (`/app/backend/uploads`). Kept: OpenAI-compatible LLM variables, Zep key, `OASIS_DEFAULT_MAX_ROUNDS=10`, `FLASK_DEBUG=false`, the volume path. Replaced: the runtime (see "Improvements"). |

The market template has no source repo (image-only). Nothing was copied from it; its README text was not reused.

## Pinned versions

| Component | Source | Version | Date | Checked |
|---|---|---|---|---|
| MiroFish source (backend + UI) | `github.com/666ghj/MiroFish` | `main` @ `7657031ac01184afe2cb220f5ee3545573b5e843` | commit 2026-10-01; app code last changed 2026-07-23 (`60757b3`, PR #742); later commits only touch star-history files | 2026-10-20 |
| MiroFish Python environment | `ghcr.io/666ghj/mirofish:v0.1.2@sha256:d236402eb35c5abfd68da63be9d19202d619da8803e173e8e34b97731180944a` | v0.1.2 (= `latest` = `sha-985f89f`, same digest); Python 3.11.15, torch 2.9.1, camel-ai 0.2.78, camel-oasis 0.2.5 | image built 2026-03-07 | 2026-10-20 |
| Lockfile delta applied on top | `backend/uv.lock` at the pinned commit | zep-cloud 3.13.0 → 3.25.0, nltk 3.9.2 → 3.10.0 (the other 183 packages are identical) | — | 2026-10-20 |
| UI build stage | `node:22.23.3-alpine3.24` (build only) | index digest `sha256:0a7108bf…2e402` | — | 2026-10-20 |
| Web runtime | `caddy:2.11.7-alpine` | index digest `sha256:d8542f48…5f75f`; Caddy v2.11.7 released 2026-10-03 | — | 2026-10-20 |
| Recommender model (runtime download) | `Twitter/twhin-bert-base` on Hugging Face (Apache-2.0, 1.1 GB safetensors) | revision chosen by OASIS (`main`) | — | 2026-10-20 |

**Why `main` and not the v0.1.2 code.** GHCR only has `v0.1.1`, `v0.1.2`, `latest` (= v0.1.2) and two `sha-*` tags; no image exists for `main`. `main` is 103 commits ahead and contains fixes that matter on a hosted deployment: Zep Cloud API limits (ontology >10 types returned HTTP 400, issue #631; search queries >400 chars), Batch ingestion, GPT-5 parameter handling, failure propagation in simulation/report stages, patched npm dependencies, and an English UI (v0.1.2's UI is Chinese-only). The dependency set is unchanged except two packages, so the backend reuses the v0.1.2 image's 4.3 GB Python layer instead of rebuilding it.

**Upgrade path:** set `MIROFISH_COMMIT` to the new commit in **both** `services/mirofish/Dockerfile` and `services/web/Dockerfile` (UI and API must match). When upstream publishes a new release image, move the backend `FROM` to it (tag + digest), compare `backend/uv.lock` with the base image's, and rename the listing if the minor version changes (e.g. v0.2).

## Architecture

```
Internet --HTTPS--> Web (Caddy, only public domain, :8080)
                     |- /healthz            -> "ok" (no auth; Railway healthcheck)
                     |- /health             -> MiroFish /health (no auth; static JSON)
                     '- everything else      -> HTTP basic auth (BASIC_AUTH_USERNAME / BASIC_AUTH_PASSWORD)
                          |- /api/*         -> MiroFish :5001 (cross-site requests refused with 403)
                          '- /*             -> static Vue UI (built from the same commit), SPA fallback
MiroFish (private, :5001, volume /app/backend/uploads)
   |- Flask API (upstream backend/run.py, werkzeug threaded server)
   |- per-simulation subprocess: OASIS Twitter + Reddit simulation (torch, twhin-bert recommender)
   |- files on the volume: projects/, simulations/ (SQLite DBs, logs), reports/, .cache/huggingface
   '- outbound: LLM provider (OpenAI-compatible), Zep Cloud API, huggingface.co (first Twitter run)
```

### Deviations from upstream `docker-compose.yml` / `Dockerfile` (at `7657031`) and why

- **Two services instead of one dev container.** Upstream's image runs `npm run dev`: the Vite dev server (:3000) and Flask (:5001) side by side, and the browser is expected to reach both. Railway routes one domain to one port, and Vite's dev server is not meant to be public. Here the UI is built once with `vite build` and served by Caddy, which also proxies `/api/*`.
- **`VITE_API_BASE_URL=/` at UI build time.** Upstream's axios client falls back to `http://localhost:5001` (the visitor's own machine) when this is unset. `/` keeps all API calls on the public origin. This is a build setting upstream supports, not a source change.
- **Login added.** MiroFish has no authentication, and every project/simulation/report endpoint spends LLM and Zep credits. Caddy requires basic auth with a generated password, blocks cross-site API calls (`Sec-Fetch-Site`), strips the `Authorization` header before the backend, and the backend has no public domain.
- **Backend binds `::`** (`FLASK_HOST`), port from `PORT`. Werkzeug's server is synchronous (no asyncio `IPV6_V6ONLY`), so one socket serves Railway's IPv4 healthcheck and IPv6 private networking (Rules 8.1, 8.2, 8.14).
- **Model cache on the volume.** OASIS downloads `Twitter/twhin-bert-base` (1.1 GB) for Twitter simulations; `HF_HOME` points into the volume so it is fetched once, not after every redeploy.
- **Thread pools sized to the CPU quota** (`OMP/MKL/OPENBLAS/NUMEXPR` threads from `/sys/fs/cgroup/cpu.max`, max 8, override `MIROFISH_CPU_THREADS`), per Rule 8.15. Torch would otherwise start one thread per host core.
- **Start-up checks** in `start.sh`: clear errors for missing keys, `ZEP_API_URL` (unsupported upstream) and non-numeric limits; empty optional variables are dropped so upstream defaults apply.
- **Generated `SECRET_KEY`** instead of upstream's built-in default.
- **Not used from upstream:** the root `concurrently` dev runner and the Vite dev server.

### What could not be self-hosted

- **Zep Cloud is required.** MiroFish talks to Zep only through the `zep-cloud` SDK and refuses a custom `ZEP_API_URL` (`backend/app/config.py`, `backend/app/utils/zep.py`), so a self-hosted Zep/Graphiti server cannot be plugged in without changing MiroFish's code. Upstream says the free monthly quota covers simple use; its issue #261 shows the free plan's rate limit (HTTP 429) breaking report generation on larger runs.
- **LLM:** any OpenAI-compatible endpoint. A self-hosted model server could be added as another service, but it would need GPUs for usable speed (Railway has none), so it is not part of this template.
- **No database service:** MiroFish stores everything as files (JSON, SQLite per simulation) under `backend/uploads`, so Postgres/Redis would have no function.

## Services

Service names matter: `MIROFISH_BACKEND` on Web references `MiroFish`. Creation order does not matter; Web starts without the backend and returns 502 for `/api/*` until it is up.

### Web

- **Source:** GitHub repo `baranberkay96/mirofish-railway`, root directory `/services/web` (Dockerfile: Node stage builds the UI from the pinned commit, Caddy stage serves it)
- **Start command:** image default (`entrypoint.sh` hashes the password, then `caddy run`)
- **Healthcheck:** `/healthz` (timeout 120 s)
- **Public domain:** yes → target port `8080`
- **TCP proxy:** none
- **Volume:** none
- **Restart policy:** ALWAYS
- **Replicas:** 1

| Variable | Value | Description |
|---|---|---|
| `PORT` | `8080` | Caddy port (public domain target); only /healthz and /health skip the login. |
| `BASIC_AUTH_USERNAME` | `admin` | Login name for the MiroFish UI and API (letters, digits, . _ @ -). |
| `BASIC_AUTH_PASSWORD` | `${{secret(32, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}}` | Login password for the MiroFish UI and API. Generated; read it here. |
| `MIROFISH_BACKEND` | `${{MiroFish.RAILWAY_PRIVATE_DOMAIN}}:5001` | Private address of the MiroFish backend that /api/* is forwarded to. |

### MiroFish

- **Source:** GitHub repo `baranberkay96/mirofish-railway`, root directory `/services/mirofish` (Dockerfile: v0.1.2 image + pinned source + `uv sync --frozen`)
- **Start command:** image default (`start.sh` → `.venv/bin/python run.py`)
- **Healthcheck:** `/health` (timeout 600 s)
- **Public domain:** no (private network only)
- **TCP proxy:** none
- **Volume:** `/app/backend/uploads`
- **Restart policy:** ALWAYS
- **Replicas:** 1

| Variable | Value | Description |
|---|---|---|
| `PORT` | `5001` | Backend (Flask) listen port; Railway health-checks /health on it. |
| `LLM_API_KEY` | *(required, no default)* | Required. API key of your OpenAI-compatible LLM provider (billed by that provider). |
| `LLM_BASE_URL` | `https://api.openai.com/v1` | OpenAI-compatible API base URL (OpenAI, DashScope, OpenRouter, vLLM, ...). |
| `LLM_MODEL_NAME` | `gpt-4o-mini` | Model id used for graph building, agent personas, simulation and reports. |
| `ZEP_API_KEY` | *(required, no default)* | Required. Zep Cloud API key (app.getzep.com) for the knowledge graph and agent memory. |
| `OASIS_DEFAULT_MAX_ROUNDS` | `10` | Default simulation rounds. More rounds = many more LLM calls and cost. |
| `LLM_BOOST_API_KEY` | *(empty)* | Optional. Second OpenAI-compatible key; parallel runs use it for the Reddit agents. |
| `LLM_BOOST_BASE_URL` | *(empty)* | Optional. Base URL for LLM_BOOST_API_KEY (set all three LLM_BOOST_* or none). |
| `LLM_BOOST_MODEL_NAME` | *(empty)* | Optional. Model id for LLM_BOOST_API_KEY. |
| `SECRET_KEY` | `${{secret(48, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}}` | Flask secret key (generated; replaces upstream's built-in default). |
| `FLASK_DEBUG` | `false` | Keep false. true turns on Flask debug mode, never for a public deployment. |
| `FLASK_HOST` | `::` | Listen address. :: serves IPv4 and IPv6; use 0.0.0.0 only if IPv4-only is needed. |
| `MIROFISH_CPU_THREADS` | *(empty)* | Optional. Torch/BLAS threads for simulations; empty = from CPU quota, max 8. |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `30` | Shutdown grace so running simulation processes are stopped cleanly on redeploy. |

`LLM_MODEL_NAME` default is upstream's own code default (`backend/app/config.py`). Upstream's README suggests Alibaba DashScope (`https://dashscope.aliyuncs.com/compatible-mode/v1`, `qwen-plus`); any OpenAI-compatible provider works. Further upstream knobs that can be added as variables: `REPORT_AGENT_MAX_TOOL_CALLS` (5), `REPORT_AGENT_MAX_REFLECTION_ROUNDS` (2), `REPORT_AGENT_TEMPERATURE` (0.5).

## Improvements over market templates

| # | Market template (`mirofish`) | This template |
|---|---|---|
| 1 | `ghcr.io/666ghj/mirofish:latest` (moving tag; its README says v0.1.2) | Pinned: v0.1.2 image by digest as the Python base, MiroFish source pinned to a full commit SHA, Caddy and Node pinned |
| 2 | v0.1.2 code: Chinese-only UI; known Zep Cloud failures (ontology >10 types → HTTP 400, #631; 400-char search limit) | `main` @ `7657031` with those fixes, English/Chinese UI switch, patched npm dependencies |
| 3 | No login: anyone with the URL can upload documents and run simulations on the owner's LLM and Zep accounts | Basic auth on everything except two health probes; generated password; cross-site API calls refused; backend has no public domain |
| 4 | Runs `npm run dev` (Vite dev server + Flask dev runner via `concurrently`) and patches `vite.config.js` with `sed` at every start | UI built once (`vite build`) and served as static files by Caddy; no start-time source patching |
| 5 | `VITE_API_BASE_URL` unset, so the v0.1.2 UI sends API calls to `http://localhost:5001` in the visitor's browser (from reading the source; not deploy-tested) | `VITE_API_BASE_URL=/`; Caddy forwards `/api/*` over the private network |
| 6 | No healthcheck | `/healthz` (Web) and `/health` (MiroFish), `PORT` set on both (Rule 8.1) |
| 7 | `LLM_API_KEY` / `ZEP_API_KEY` optional with empty defaults: an unconfigured deploy exits in `Config.validate()` and `concurrently --kill-others` takes the UI down with it | Both marked required in the template; `start.sh` prints which key is missing |
| 8 | Twitter simulations download the 1.1 GB twhin-bert model into the container after every redeploy | `HF_HOME` on the volume; downloaded once |
| 9 | Torch thread pool sized to the host's cores | Threads from the cgroup CPU quota, max 8, override variable (Rule 8.15) |
| 10 | Flask `SECRET_KEY` left at upstream's hard-coded default | Generated with `secret()` |
| 11 | Default LLM endpoint DashScope (`qwen-plus`) | Upstream's code default (OpenAI-compatible `https://api.openai.com/v1`, `gpt-4o-mini`); DashScope documented as an option |
| 12 | Marketing copy: "AI prediction engine", "generate prediction reports" | Describes what runs (agent simulation on mock social platforms) without forecast claims |

## Scaling

- **MiroFish: 1 replica.** Task progress, running simulation processes and their IPC live in the Flask process, and the data is on the volume (replicas cannot share it). Scale vertically: each running simulation is a separate subprocess (roughly 2–3 GB during a Twitter run), so allow more RAM for parallel simulations. `OASIS_DEFAULT_MAX_ROUNDS` and the agent count chosen in the UI drive LLM cost far more than Railway cost.
- **Web:** stateless, one replica is plenty; replicas work (no volume).
- Parallel throughput is usually bounded by the LLM provider's and Zep's rate limits. `LLM_BOOST_*` lets the Reddit half of a parallel run use a second provider/key.

## Resource estimate

Prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month (Railway pricing page, checked 2026-10-20). Builds and image storage are not billed. Figures are **estimates from the code paths and package sizes, not measurements** (nothing was run). LLM and Zep usage are billed by those providers and usually dominate.

| Service | Idle RAM | Typical RAM | vCPU idle / busy | Volume |
|---|---|---|---|---|
| Web (Caddy + static files) | 15 MB | 30 MB | 0.00 / 0.02 | — |
| MiroFish – API process (Flask, zep-cloud, openai) | 200–300 MB | 300–500 MB (graph build, report) | 0.01 / 0.1 | — |
| MiroFish – simulation subprocess (only while a simulation runs) | 0 | 2–3 GB (torch + twhin-bert + agents) | — / 0.5–2 | — |
| Volume | — | — | — | 0.1 GB at start; ~1.3 GB after the first Twitter run (model cache) + projects/simulations |
| **Total** | **≈ 0.3 GB** | **≈ 0.4 GB, 2.5–3.5 GB while simulating** | **≈ 0.01 / up to 2** | **≈ 1.5 GB** |

- **Idle:** 0.3 GB × $10 + 0.01 vCPU × $20 + 1.5 GB × $0.15 ≈ **$3.5/month**.
- **Typical (a few simulations a week, ≈ 20 simulation-hours/month):** each simulation-hour adds ≈ 2.5 GB-h and ≈ 1 vCPU-h ≈ $0.06 → **≈ $5–7/month**.
- **Heavy (simulations ~8 h a day):** ≈ 240 simulation-hours → **≈ $18–25/month**; simulations around the clock ≈ $55–65/month.
- **Minimum plan: Hobby.** The backend image is ~4.8 GB compressed (Trial/Free image limit: 4 GB), and a Twitter simulation needs more than Trial's 1 GB RAM. Hobby's 5 GB volume limit is enough for the model cache plus many simulations. Pro for teams running several simulations in parallel.

## Verification checklist

None of these ran yet (no Docker allowed, see "Local verification"). On the first Railway deploy:

1. **Builds:** Web build log shows `npm ci`, `vite build`, then `Valid configuration` from `caddy validate`. MiroFish build log shows `uv sync` changing only `zep-cloud` and `nltk` (plus the editable `mirofish-backend` project) and the three import checks passing.
2. **Health:** both services Active. `curl -i https://{web-domain}/healthz` → 200 `ok` without credentials; `curl https://{web-domain}/health` → `{"service":"MiroFish Backend","status":"ok"}`.
3. **Logs:** MiroFish shows `[mirofish] listen [::]:5001 model=gpt-4o-mini llm_host=api.openai.com max_rounds=10 threads=N hf_home=/app/backend/uploads/.cache/huggingface` and no "is not a mounted volume" warning. Web shows `MiroFish UI on :8080, /api -> mirofish.railway.internal:5001`.
4. **Auth:** `curl -i https://{web-domain}/` and `curl -i https://{web-domain}/api/graph/project/list` → 401. With `-u admin:{BASIC_AUTH_PASSWORD}` → 200. `curl -u admin:{pw} -H 'Sec-Fetch-Site: cross-site' https://{web-domain}/api/graph/project/list` → 403.
5. **UI:** open the Web URL, sign in from the browser prompt, switch the language to English (switcher in the header), reload a deep link such as `/process/x` → the SPA loads (no 404).
6. **End to end (needs real keys):** upload a short text/PDF, describe a scenario → ontology and Zep graph build complete; environment setup creates agent personas; start a simulation with few rounds → Twitter and Reddit actions appear; generate the report; chat with one agent.
7. **Model cache:** after the first Twitter simulation, `/app/backend/uploads/.cache/huggingface` holds `models--Twitter--twhin-bert-base` (~1.1 GB); a second simulation after a redeploy does not download it again.
8. **Persistence:** redeploy MiroFish → projects, simulations and reports are still listed in the history view.
9. **Threads:** in a simulation's `simulation.log`, no thread-oversubscription stalls; if CPU use is pinned while LLM calls are idle, lower `MIROFISH_CPU_THREADS`.
10. **IPv4 health over `::`:** the healthcheck in step 2 passing proves the dual-stack bind; if MiroFish never becomes healthy, set `FLASK_HOST=0.0.0.0` and redeploy.

## Open questions

- **Nothing has run yet.** No image was built or started (no Docker this round). Railway's deploy test is the first real run.
- **`uv sync --frozen` on the v0.1.2 venv** is expected to touch two packages only (lockfiles compared package by package). If uv decides to reinstall more, the build still works but takes longer and the image grows; if it fails, fall back to building the environment from scratch (`python:3.11` + `uv sync --frozen`, like upstream's Dockerfile).
- **Import smoke test at build** (`import oasis, camel`) assumes those imports do no network calls. If the build fails there for network reasons, drop that line; the API import check stays.
- **`gpt-4o-mini` default** is upstream's code default. Providers retire models; it is a variable. GPT-5-family ids work in MiroFish's own client (upstream compatibility layer), but the OASIS agents go through CAMEL's OpenAI client, which was not checked with GPT-5 parameters.
- **Werkzeug dev server:** upstream ships only `app.run(threaded=True)`. It prints a "development server" warning. A multi-worker WSGI server would break MiroFish's in-process task and simulation state, so it was not swapped.
- **Language default:** the UI starts in Chinese until a visitor picks English (stored in the browser). Changing the default would mean modifying MiroFish's source (AGPL obligations), so it was left as upstream ships it.
- **Simulations do not survive a redeploy** (upstream has no resume, issue #688): the shutdown handler stops them. Avoid redeploying MiroFish while a simulation runs.
- **twhin-bert revision** is chosen by OASIS at runtime (Hugging Face `main`); it cannot be pinned without code changes. Hugging Face anonymous rate limits could slow the first download; `HF_TOKEN` can be added as a variable.
- **Zep Cloud free plan** rate limits (HTTP 429, issue #261) can fail report generation on larger runs; that is a Zep account limit, not a Railway one.
- **Repo name** `baranberkay96/mirofish-railway` follows the existing convention; adjust `source.repo` if the published repo is named differently.

## Local verification (2026-10-20)

Docker was not used (instruction for this round). Checks that ran:

| Check | Result |
|---|---|
| `sh -n`, `dash -n`, `bash -n` on `services/mirofish/start.sh` and `services/web/entrypoint.sh` | **Pass** |
| `start.sh` logic under `dash` with stubbed paths: missing keys, empty optionals dropped, cgroup quota 2 / 1.5 / 32 CPUs → 2 / 2 / 8 threads, no quota → fallback, override, bad thread/round/port values, `ZEP_API_URL` rejection, partial `LLM_BOOST_*` warning | **Pass** (11 cases; keys never printed) |
| `entrypoint.sh` with a stub `caddy`: password reaches `hash-password` on stdin (not argv), is unset before `caddy run`; bad username, short password, missing backend, failed hash rejected | **Pass** |
| `template.json` parses; every variable has a description; `_tools/to_serialized.py` converts it (2 services, volume, public domain only on Web) | **Pass** |
| Caddyfile constructs checked against Caddy v2.11.7 source: `basic_auth bcrypt <realm>` (hash cache on), repeated `header` matcher lines are OR'ed, named matchers inside `handle`, directive order (`basic_auth` before nested `handle`, `respond` before `reverse_proxy`), `hash-password` reads stdin and defaults to bcrypt | **Pass** (source reading; `caddy validate` runs in the Docker build) |
| Image tags exist (registry API, no pull): `ghcr.io/666ghj/mirofish:v0.1.2` = `latest` = `sha-985f89f` (`sha256:d236402e…`, amd64), `caddy:2.11.7-alpine`, `node:22.23.3-alpine3.24` | **Pass** |
| Base image contents (manifest/config + streamed listing of the dependency layer): venv at `/app/backend/.venv`, `bin/python → /usr/local/bin/python3`, revision label `985f89f` | **Pass** |
| `uv.lock` v0.1.2 vs pinned commit: same 185 packages, only zep-cloud and nltk versions differ | **Pass** |
| Pinned commit == `_upstream` copy (git blob hashes of `graph.py`, `simulation_runner.py`, `uv.lock`, `package-lock.json`, `Dockerfile`) | **Pass** |
| Upstream code paths read: API base URL fallback, Flask bind (`FLASK_HOST`/`FLASK_PORT`), werkzeug 3.1.4 has no `IPV6_V6ONLY`, storage under `backend/uploads`, `ZEP_API_URL` rejection, simulation subprocess uses `sys.executable`, OASIS 0.2.5 Twitter platform uses `twhin-bert` | **Pass** |
| `docker build --platform linux/amd64` of both services; running the stack | **Not run (unverified)** |
