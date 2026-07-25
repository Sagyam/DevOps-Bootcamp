# Single-stage build. A production image would use a multi-stage build to drop
# the compiler and dev dependencies, but a single stage is easier to read and
# easier to poke at with `docker compose exec api sh` during the lab.
FROM node:22-alpine

# Prisma's query engine is a native binary that links against OpenSSL.
# Alpine does not ship it by default, so we install it explicitly.
RUN apk add --no-cache openssl

WORKDIR /app

# Copy manifests first so Docker can cache `npm install` across code changes.
COPY package.json ./
RUN npm install

# `prisma generate` reads schema.prisma and writes a typed client into
# node_modules/.prisma. It must run before we compile TypeScript, because the
# generated types are what our code imports.
COPY prisma ./prisma
RUN npx prisma generate

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

EXPOSE 3000

# CHANGED ON DAY 3. `-r` preloads dist/tracing.js before dist/main.js.
# OpenTelemetry's automatic instrumentation patches libraries as they are
# required, so it has to win the race to load first. See app/src/tracing.ts.
CMD ["node", "-r", "./dist/tracing.js", "dist/main.js"]
