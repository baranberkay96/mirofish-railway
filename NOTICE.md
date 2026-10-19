# Notice

## Upstream software

| Software | License | How it is used here |
|---|---|---|
| MiroFish (backend, web UI) — MiroFish Team (`backend/pyproject.toml`), github.com/666ghj/MiroFish | AGPL-3.0 | Backend: Docker image `ghcr.io/666ghj/mirofish:v0.1.2` (pinned by digest) as the base, with the upstream source of commit `7657031ac01184afe2cb220f5ee3545573b5e843` fetched at build time. UI: built at build time from the same commit with upstream's `vite build`. **No MiroFish file is modified**; the only UI build setting is `VITE_API_BASE_URL=/`, which upstream's code reads. |
| OASIS (`camel-oasis` 0.2.5) and CAMEL (`camel-ai` 0.2.78) — CAMEL-AI.org | Apache-2.0 | Simulation framework, installed in the upstream image |
| PyTorch, Transformers, sentence-transformers, other Python dependencies | Various OSI licenses (BSD, Apache-2.0, MIT, ...) | Installed in the upstream image per MiroFish's `backend/uv.lock` |
| `Twitter/twhin-bert-base` model | Apache-2.0 (Hugging Face model card) | Downloaded at runtime by OASIS for Twitter simulations; cached on the volume |
| Caddy | Apache-2.0 | `caddy:2.11.7-alpine` (Docker Official Image), web edge |
| Node.js | MIT | `node:22.23.3-alpine3.24`, build stage only (not in the running image) |

Third-party services (Zep Cloud, your LLM provider, Hugging Face Hub) are used under their own terms and bill you directly where applicable.

## Verified against

| What | Upstream file | Ref | URL | Checked |
|---|---|---|---|---|
| Container layout, start command, ports, volume | `Dockerfile`, `docker-compose.yml`, `.dockerignore` | `7657031` (files unchanged since v0.1.2) | https://github.com/666ghj/MiroFish/tree/7657031ac01184afe2cb220f5ee3545573b5e843 | 2026-10-20 |
| Environment variables and defaults | `.env.example`, `backend/app/config.py`, `backend/run.py`, `backend/scripts/run_parallel_simulation.py` | `7657031` | same | 2026-10-20 |
| Zep Cloud only (no `ZEP_API_URL`) | `backend/app/config.py`, `backend/app/utils/zep.py` | `7657031` | same | 2026-10-20 |
| UI API base URL, router mode, build script | `frontend/src/api/index.js`, `frontend/src/router/index.js`, `frontend/package.json`, `frontend/vite.config.js` | `7657031` and `v0.1.2` | same | 2026-10-20 |
| Storage paths | `backend/app/models/project.py`, `backend/app/services/simulation_manager.py`, `backend/app/services/report_agent.py`, `backend/app/services/simulation_runner.py` | `7657031` | same | 2026-10-20 |
| Dependency delta | `backend/uv.lock` | `v0.1.2` vs `7657031` | https://github.com/666ghj/MiroFish/compare/v0.1.2...7657031ac01184afe2cb220f5ee3545573b5e843 | 2026-10-20 |
| Release image and tags | GHCR registry API (`tags/list`, manifests, config labels `org.opencontainers.image.version=v0.1.2`, revision `985f89f`) | `v0.1.2`, `latest`, `sha-985f89f` | https://github.com/666ghj/MiroFish/pkgs/container/mirofish | 2026-10-20 |
| Image publishing rules | `.github/workflows/docker-image.yml` | `7657031` | same repo | 2026-10-20 |
| Twitter recommender model | `oasis/environment/env.py`, `oasis/social_platform/recsys.py` | camel-ai/oasis `v0.2.5` | https://github.com/camel-ai/oasis/tree/v0.2.5 | 2026-10-20 |
| Flask dev server IPv6 behaviour | `src/werkzeug/serving.py` | werkzeug `3.1.4` (lockfile version) | https://github.com/pallets/werkzeug/blob/3.1.4/src/werkzeug/serving.py | 2026-10-20 |
| Caddy directives used | `modules/caddyhttp/caddyauth/caddyfile.go`, `command.go`, `modules/caddyhttp/matchers.go`, `caddyconfig/httpcaddyfile/directives.go` | Caddy `v2.11.7` | https://github.com/caddyserver/caddy/tree/v2.11.7 | 2026-10-20 |

## Files in this template

All files were written for this template; none were copied from MiroFish, from the marketplace template or from other templates' upstreams.

| File | Notes |
|---|---|
| `services/mirofish/Dockerfile`, `services/mirofish/start.sh` | Written for this template. Fetches and runs unmodified MiroFish code; `start.sh` only sets environment variables and execs upstream's `backend/run.py`. |
| `services/web/Dockerfile`, `services/web/Caddyfile`, `services/web/entrypoint.sh` | Written for this template (same basic-auth gateway pattern as other templates in this collection). |
| `TEMPLATE.md`, `template.json`, `README.md`, `NOTICE.md` | Written for this template. |

## AGPL-3.0 notes (practical guidance, not legal advice)

- MiroFish is AGPL-3.0. This template does not redistribute a modified MiroFish: Railway builds it from upstream's published image and source at a fixed commit, and the UI links to the upstream repository.
- AGPL section 13 applies when someone **modifies** MiroFish and lets users interact with it over a network: the modified source must then be offered to those users. Anyone who patches MiroFish in their deployment (for example to change the default language) should publish the patched source and link to it in the UI.
- The wrapper files above are separate programs that start or proxy MiroFish; they are not derived from MiroFish's code.
- Commercial operators should have their own counsel confirm AGPL obligations for their use.

## Reference only (not copied)

- Marketplace template `mirofish` ("Mirofish", image `ghcr.io/666ghj/mirofish:latest`, no source repository): read for its variable set, volume path and start command. No text or files copied.
- The `_upstream/666ghj__MiroFish` working copy matches commit `7657031` (blob hashes compared); it was read, never executed.

## Trademarks

"MiroFish" and its logo belong to their respective owners; "Zep" to its owner; "Railway" to Railway Corporation. This is a community template and is not affiliated with or endorsed by the MiroFish team, Shanda Group, CAMEL-AI, Zep or Railway.
