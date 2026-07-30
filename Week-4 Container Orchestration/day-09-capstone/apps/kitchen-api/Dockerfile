FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --omit=dev --no-audit --no-fund

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
# Trust the in-cluster CA so plain fetch() can talk to the Kubernetes API server.
ENV NODE_EXTRA_CA_CERTS=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src/ ./src/
USER node
EXPOSE 8080
CMD ["node", "src/server.js"]
