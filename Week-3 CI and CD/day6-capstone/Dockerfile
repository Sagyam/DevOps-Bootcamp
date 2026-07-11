# Single stage is honest here: there's nothing to compile and no dependencies.
# (If you add deps later: split into a build stage that runs `npm ci`, then copy
#  node_modules into a slim runtime stage — exactly your Docker Day 4 lesson.)
FROM node:26-alpine

ENV NODE_ENV=production
WORKDIR /app

# Bake the version in at build time so /health can report exactly what shipped.
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
ENV PORT=8080

COPY app/package.json ./
COPY app/src ./src

EXPOSE 8080
USER node
CMD ["node", "src/server.js"]
