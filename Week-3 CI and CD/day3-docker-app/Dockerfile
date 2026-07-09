# Multi-stage build — the exact idea from your Docker Day 4 lesson, now
# driven by CI instead of your laptop.
#
# Stage 1 "build": has everything needed to install/compile.
# Stage 2 "runtime": copies only what's needed to *run*, so the shipped
# image is small and has a smaller attack surface.

# ---- build stage ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
# This app has no runtime deps, but we still model the real flow:
RUN npm install --omit=dev
COPY src ./src

# ---- runtime stage ----
FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
# Run as a non-root user — a security habit CI should never skip.
USER node
COPY --from=build /app /app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "src/server.js"]
