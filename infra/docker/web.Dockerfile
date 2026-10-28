# Build from the repo root

ARG NODE_VERSION=24.22.1

FROM node:${NODE_VERSION}-bookworm-slim AS build

RUN npm install --global pnpm@12.14.0

WORKDIR /app/web
COPY web/package.json web/pnpm-lock.yaml web/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY web ./
# The type check reads the permission rules the server owns
COPY apps/hearth/priv/permissions.yml /app/apps/hearth/priv/permissions.yml
RUN pnpm build && pnpm prune --prod

FROM node:${NODE_VERSION}-bookworm-slim

ENV NODE_ENV=production \
  PORT=3000 \
  HOST=0.0.0.0

WORKDIR /app
COPY --from=build --chown=node:node /app/web/package.json ./
COPY --from=build --chown=node:node /app/web/node_modules ./node_modules
COPY --from=build --chown=node:node /app/web/build ./build
COPY --from=build --chown=node:node /app/web/scripts ./scripts
USER node

EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/favicon.svg').then((r) => process.exit(r.status < 500 ? 0 : 1)).catch(() => process.exit(1))"

CMD ["node", "scripts/serve.mjs"]
