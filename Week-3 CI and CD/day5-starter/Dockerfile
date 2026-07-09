FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
# Bake the version in at build time so /health can report exactly what shipped.
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
USER node
COPY src ./src
EXPOSE 3000
CMD ["node", "src/server.js"]
