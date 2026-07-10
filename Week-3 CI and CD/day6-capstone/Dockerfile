FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY src ./src

FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
USER node
COPY --from=build /app /app
EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://localhost:3001/health || exit 1
CMD ["node", "src/server.js"]
