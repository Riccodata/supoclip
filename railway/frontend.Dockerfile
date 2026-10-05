# Railway build of the SupoClip frontend (production only).
# Mirrors the builder and runner stages of frontend/Dockerfile without its
# BuildKit cache mount: Railway rejects cache mount ids that lack its
# service-id prefix. Build context is the repository root.
FROM node:22-bookworm-slim AS base

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN npm install -g pnpm@10.27.0

FROM base AS builder
WORKDIR /app

# Install OpenSSL (required for Prisma)
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --ignore-scripts

COPY frontend/ .

RUN pnpm exec prisma generate

ENV NEXT_TELEMETRY_DISABLED=1
# Skip linting during build (generated Prisma code has lint warnings)
ENV SKIP_LINT=1

# Build-time env vars (NEXT_PUBLIC_* must be present at build time).
# Railway passes service variables with these names in as build args.
ARG NEXT_PUBLIC_API_URL=http://localhost:8000
ARG NEXT_PUBLIC_APP_URL=http://localhost:3107
ARG NEXT_PUBLIC_SELF_HOST=true
ARG NEXT_PUBLIC_PRO_PRICE_MONTHLY=10
ARG NEXT_PUBLIC_SCALE_PRICE_MONTHLY=50
ARG NEXT_PUBLIC_FREE_PLAN_TASK_LIMIT=10
ARG NEXT_PUBLIC_PRO_PLAN_TASK_LIMIT=50
ARG NEXT_PUBLIC_SCALE_PLAN_TASK_LIMIT=300
ARG NEXT_PUBLIC_DATAFAST_WEBSITE_ID=
ARG NEXT_PUBLIC_DATAFAST_DOMAIN=
ARG NEXT_PUBLIC_DATAFAST_ALLOW_LOCALHOST=false
ARG NEXT_PUBLIC_SITE_NAME=
ARG NEXT_PUBLIC_PRIVATE_MODE=false
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NEXT_PUBLIC_APP_URL=${NEXT_PUBLIC_APP_URL}
ENV NEXT_PUBLIC_SELF_HOST=${NEXT_PUBLIC_SELF_HOST}
ENV NEXT_PUBLIC_PRO_PRICE_MONTHLY=${NEXT_PUBLIC_PRO_PRICE_MONTHLY}
ENV NEXT_PUBLIC_SCALE_PRICE_MONTHLY=${NEXT_PUBLIC_SCALE_PRICE_MONTHLY}
ENV NEXT_PUBLIC_FREE_PLAN_TASK_LIMIT=${NEXT_PUBLIC_FREE_PLAN_TASK_LIMIT}
ENV NEXT_PUBLIC_PRO_PLAN_TASK_LIMIT=${NEXT_PUBLIC_PRO_PLAN_TASK_LIMIT}
ENV NEXT_PUBLIC_SCALE_PLAN_TASK_LIMIT=${NEXT_PUBLIC_SCALE_PLAN_TASK_LIMIT}
ENV NEXT_PUBLIC_DATAFAST_WEBSITE_ID=${NEXT_PUBLIC_DATAFAST_WEBSITE_ID}
ENV NEXT_PUBLIC_DATAFAST_DOMAIN=${NEXT_PUBLIC_DATAFAST_DOMAIN}
ENV NEXT_PUBLIC_DATAFAST_ALLOW_LOCALHOST=${NEXT_PUBLIC_DATAFAST_ALLOW_LOCALHOST}
ENV NEXT_PUBLIC_SITE_NAME=${NEXT_PUBLIC_SITE_NAME}
ENV NEXT_PUBLIC_PRIVATE_MODE=${NEXT_PUBLIC_PRIVATE_MODE}

RUN pnpm run build

# Next's standalone output is a Node server, so production only needs Node.
FROM node:22-bookworm-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Install OpenSSL (required for Prisma) and curl for healthchecks
RUN apt-get update && apt-get install -y openssl curl && rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 1001 nodejs
RUN useradd --system --uid 1001 --gid nodejs nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copy Prisma generated client and schema
COPY --from=builder --chown=nextjs:nodejs /app/src/generated/prisma ./src/generated/prisma
COPY --from=builder /app/prisma ./prisma

COPY --from=builder --chown=nextjs:nodejs \
    /app/src/generated/prisma/libquery_engine-debian-openssl-3.0.x.so.node \
    /app/prisma-engine/libquery_engine-debian-openssl-3.0.x.so.node
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma-engine/libquery_engine-debian-openssl-3.0.x.so.node

USER nextjs

EXPOSE 3107

ENV PORT=3107
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
