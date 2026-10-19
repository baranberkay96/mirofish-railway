# Deploy and Host MiroFish with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/mirofish-v01-swarm-intelligence-engine?referralCode=20H68q)

MiroFish is an open-source (AGPL-3.0) multi-agent simulation engine: feed it documents and a scenario, and it builds a knowledge graph, turns the people and organisations in it into LLM agents, lets them post and react on simulated social platforms, and writes up what happened. This community template runs it behind a login on one HTTPS URL.

## About Hosting MiroFish

MiroFish has two parts: a Vue web UI and a Python backend that calls your LLM, keeps the knowledge graph and agent memory in Zep Cloud, and starts each simulation as a separate CAMEL-AI OASIS process (Twitter-like and Reddit-like platforms, with a Hugging Face recommender model). Upstream ships a single development container with no authentication. This template builds the UI once and serves it from Caddy, puts HTTP basic auth with a generated password in front of the UI and API, keeps the backend on the private network, pins the MiroFish source to a commit, and stores projects, simulations, reports and the model cache on a volume.

## Common Use Cases

- Rehearse how a public announcement, policy draft or news story might be discussed by different groups before you publish it
- Explore audience reactions to a product launch or campaign with personas derived from your own briefing documents
- Classroom and research experiments on opinion dynamics and LLM agent behaviour
- Play through "what if" scenarios from a novel or story world and interview individual characters afterwards

Results are LLM-generated simulations, not forecasts; treat them as a structured brainstorm.

## Dependencies for MiroFish Hosting

- MiroFish backend: upstream source at commit `7657031` on the official `ghcr.io/666ghj/mirofish:v0.1.2` Python environment (built from this repository)
- MiroFish web UI built from the same commit, served by Caddy 2.11 with basic auth (built from this repository)
- An OpenAI-compatible LLM API key (OpenAI, Alibaba DashScope, OpenRouter, a self-hosted vLLM endpoint, ...) — required
- A Zep Cloud API key for the knowledge graph and agent memory — required; MiroFish does not support self-hosted Zep
- A Railway volume (included) for projects, simulations, reports and the 1.1 GB recommender model cache

### Deployment Dependencies

- MiroFish source, docs and releases: https://github.com/666ghj/MiroFish
- MiroFish container image: https://github.com/666ghj/MiroFish/pkgs/container/mirofish
- OASIS simulation framework (CAMEL-AI): https://github.com/camel-ai/oasis
- Zep Cloud (API key): https://app.getzep.com
- OpenAI API keys: https://platform.openai.com/api-keys
- Alibaba Cloud Model Studio / DashScope (upstream's suggested provider): https://bailian.console.aliyun.com
- Caddy basic auth: https://caddyserver.com/docs/caddyfile/directives/basic_auth

### Implementation Details

| Service | Built from | Role | Public |
|---|---|---|---|
| Web | Caddy 2.11.7 + MiroFish UI (`services/web`) | Login, static UI, forwards `/api/*` to MiroFish | **yes** |
| MiroFish | MiroFish backend (`services/mirofish`) | Flask API, simulation processes; volume at `/app/backend/uploads` | no |

**Before you deploy:** create a Zep Cloud API key and an LLM API key, and enter them as `ZEP_API_KEY` and `LLM_API_KEY` on the MiroFish service. For a provider other than OpenAI, also set `LLM_BASE_URL` and `LLM_MODEL_NAME` (for DashScope: `https://dashscope.aliyuncs.com/compatible-mode/v1` and `qwen-plus`).

**First login**

1. Wait until both services are Active. The first MiroFish build pulls a large base image (about 4.8 GB), so it takes several minutes.
2. Open the Web service URL. Your browser asks for a user name and password: use `BASIC_AUTH_USERNAME` (default `admin`) and `BASIC_AUTH_PASSWORD` from the **Web** service variables.
3. The interface starts in Chinese; pick English with the language switcher in the top bar (remembered by your browser).
4. Upload one or more PDF, Markdown or text files (up to 50 MB), describe what you want to simulate, and follow the five steps: graph building, environment setup, simulation, report, interaction.

**Cost control:** simulations make many LLM calls. Start with few agents and the default 10 rounds (`OASIS_DEFAULT_MAX_ROUNDS`), and watch your provider's usage page. LLM and Zep usage are billed by those providers, not by Railway. Zep's free plan is rate-limited, which can make report generation fail on larger runs.

**Security:** MiroFish itself has no user accounts. Every page and API call goes through the Web service's basic auth, API calls started by other websites are refused, and the backend has no public URL. Only `/healthz` and `/health` answer without a password. Change the password by editing `BASIC_AUTH_PASSWORD` on Web and redeploying it. Share the login only with people you trust to spend your LLM credits.

**Custom domain:** add it to the Web service; nothing else needs to change.

**Scaling:** run MiroFish as a single replica (it keeps task and simulation state in process and owns the volume) and give it more memory if you run several simulations at once; a Twitter simulation needs roughly 2–3 GB while it runs. Torch threads follow the service's CPU allowance (max 8); `MIROFISH_CPU_THREADS` overrides that. Web is stateless. Redeploying MiroFish stops running simulations, so redeploy between runs.

**Pinning and upgrading:** the MiroFish source is pinned to a full commit SHA (`MIROFISH_COMMIT`) in `services/mirofish/Dockerfile` and `services/web/Dockerfile`; change it in both files together. The backend's Python environment comes from the `v0.1.2` image pinned by digest; when upstream publishes a newer release image, move the `FROM` line to it. Caddy and Node images are pinned by tag.

This is a community template, not made, endorsed or supported by the MiroFish team. MiroFish is licensed under AGPL-3.0 and runs here unmodified; if you change its code and let others use it over the network, the AGPL asks you to offer them your modified source.

### Why Deploy MiroFish on Railway?

Railway runs the UI edge and the simulation backend as two services with private networking, managed TLS and a persistent volume, so you get a password-protected MiroFish without writing a reverse-proxy config or keeping a laptop running for long simulations. You pay only for the RAM and CPU the simulations actually use, and your documents and results stay in your own project.
