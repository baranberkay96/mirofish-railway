# MiroFish web edge for Railway: the upstream Vue UI built as static files, served by
# Caddy behind HTTP basic auth, with /api/* forwarded to the private MiroFish backend.
#
# Upgrade: change MIROFISH_COMMIT here AND in services/mirofish/Dockerfile.

FROM node:22.23.3-alpine3.24 AS ui

ARG MIROFISH_REPO=https://github.com/666ghj/MiroFish.git
ARG MIROFISH_COMMIT=7657031ac01184afe2cb220f5ee3545573b5e843

RUN apk add --no-cache git

WORKDIR /src
RUN set -eux; \
    git init -q .; \
    git fetch -q --depth 1 "$MIROFISH_REPO" "$MIROFISH_COMMIT"; \
    git -c advice.detachedHead=false checkout -q FETCH_HEAD; \
    test "$(git rev-parse HEAD)" = "$MIROFISH_COMMIT"

WORKDIR /src/frontend
# Upstream's axios client falls back to http://localhost:5001 when VITE_API_BASE_URL
# is unset, i.e. the visitor's own machine. "/" keeps API calls on this origin.
ENV VITE_API_BASE_URL=/
RUN set -eux; \
    npm ci --no-audit --no-fund; \
    npm run build; \
    test -f dist/index.html

FROM caddy:2.11.7-alpine

COPY --from=ui /src/frontend/dist /srv
COPY Caddyfile /etc/caddy/Caddyfile
COPY --chmod=0755 entrypoint.sh /usr/local/bin/mirofish-web

# Validate the config with placeholder values (real ones come from the environment at start).
RUN BASIC_AUTH_USERNAME=check \
    BASIC_AUTH_HASH='$2a$14$abcdefghijklmnopqrstuuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0' \
    MIROFISH_BACKEND=localhost:5001 \
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/mirofish-web"]
