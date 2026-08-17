# syntax=docker/dockerfile:1.7

# --- Stage 1: install production dependencies only -------------------------
# Pinned to a digest, not a tag. Tags move; digests do not. Update with:
#   docker buildx imagetools inspect node:22.17-bookworm-slim
FROM node:22.17-bookworm-slim AS deps
WORKDIR /app
# Copy manifests first so this layer is cached until dependencies change.
COPY package.json package-lock.json ./
# npm ci installs exactly the lockfile. npm install can silently drift.
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev --ignore-scripts

# --- Stage 2: full install + lint + test -----------------------------------
FROM node:22.17-bookworm-slim AS test
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run lint && npm run format && npm run test:unit

# --- Stage 3: runtime ------------------------------------------------------
FROM node:22.17-bookworm-slim AS runtime

ENV NODE_ENV=production \
    NPM_CONFIG_UPDATE_NOTIFIER=false

# dumb-init gives us a real PID 1 that forwards SIGTERM to node, which is
# what makes graceful shutdown work under Kubernetes.
RUN apt-get update \
 && apt-get install -y --no-install-recommends dumb-init=1.2.5-2 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Non-root, and the app directory is not writable by the app user.
# The node image already ships an unprivileged 'node' user (uid 1000).
COPY --chown=root:root --from=deps /app/node_modules ./node_modules
COPY --chown=root:root package.json ./
COPY --chown=root:root src ./src
COPY --chown=root:root db ./db

USER node

EXPOSE 3000

# HEALTHCHECK is for docker/compose. Kubernetes uses the probes in the
# Deployment instead — both exist because both runtimes are used.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/server.js"]

# OCI labels: populated by CI so a running image can be traced to a commit.
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.source="https://github.com/example/tiffin" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="MIT"
