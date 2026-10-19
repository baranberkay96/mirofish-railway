# MiroFish backend (Flask API + OASIS simulation runner) for Railway.
#
# Base: the official v0.1.2 image. It already contains the heavy Python
# environment (torch, camel-ai, camel-oasis, ...) at /app/backend/.venv.
# On top of it we put the MiroFish source of a pinned main commit and let uv
# apply that commit's lockfile (zep-cloud 3.13.0 -> 3.25.0, nltk 3.9.2 -> 3.10.0;
# all other 183 packages are identical), so no multi-GB dependency rebuild is needed.
#
# Upgrade: change MIROFISH_COMMIT here AND in services/web/Dockerfile (UI and API
# must come from the same commit). Move FROM to a newer release image when one exists.
FROM ghcr.io/666ghj/mirofish:v0.1.2@sha256:d236402eb35c5abfd68da63be9d19202d619da8803e173e8e34b97731180944a

ARG MIROFISH_REPO=https://github.com/666ghj/MiroFish.git
ARG MIROFISH_COMMIT=7657031ac01184afe2cb220f5ee3545573b5e843

LABEL org.opencontainers.image.source="https://github.com/666ghj/MiroFish" \
      org.opencontainers.image.revision="${MIROFISH_COMMIT}" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opencontainers.image.description="MiroFish backend, unmodified upstream source at the pinned commit"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Replace the v0.1.2 source tree with the pinned commit, keeping only the prebuilt
# virtualenv in place (moving it would copy ~9 GB into a new layer).
RUN set -eux; \
    src=/tmp/mirofish-src; \
    git init -q "$src"; \
    git -C "$src" fetch -q --depth 1 "$MIROFISH_REPO" "$MIROFISH_COMMIT"; \
    git -C "$src" -c advice.detachedHead=false checkout -q FETCH_HEAD; \
    test "$(git -C "$src" rev-parse HEAD)" = "$MIROFISH_COMMIT"; \
    rm -rf "$src/.git" "$src/backend/.venv"; \
    test -x /app/backend/.venv/bin/python; \
    find /app -mindepth 1 -maxdepth 1 ! -name backend -exec rm -rf {} +; \
    find /app/backend -mindepth 1 -maxdepth 1 ! -name .venv -exec rm -rf {} +; \
    cp -a "$src/." /app/; \
    rm -rf "$src"

WORKDIR /app/backend

ENV UV_PYTHON_DOWNLOADS=never \
    UV_LINK_MODE=copy \
    UV_NO_CACHE=1

# Apply the commit's lockfile to the existing venv, then smoke-test the imports
# the API and the simulation subprocess need.
RUN set -eux; \
    uv sync --frozen; \
    .venv/bin/python -c "import importlib.metadata as m; v = m.version('zep-cloud'); assert v == '3.25.0', v"; \
    .venv/bin/python -c "import app.api, app.services.simulation_runner"; \
    .venv/bin/python -c "import oasis, camel"; \
    rm -rf /app/backend/logs

COPY --chmod=0755 start.sh /usr/local/bin/mirofish-start

ENV PYTHONUNBUFFERED=1 \
    HF_HUB_DISABLE_TELEMETRY=1 \
    TOKENIZERS_PARALLELISM=false \
    PORT=5001

EXPOSE 5001

ENTRYPOINT ["/usr/local/bin/mirofish-start"]
CMD []
