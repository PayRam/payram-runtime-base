# syntax=docker/dockerfile:1.7
#
# PayRam runtime base image
# -------------------------
# Rarely-changing foundation for the combined PayRam image.  Builds of
# payram-core start FROM this instead of reinstalling postgres / redis
# / supervisor on every build, shaving 1–2 minutes off every CI run.
#
# Bump the tag (v1.0.0 → v1.1.0) when you change anything here.
# Bump the MAJOR tag (v1 → v2) only for breaking changes that require
# payram-core to opt in (e.g., PostgreSQL or Node.js major-version upgrade).
#
# Rebuild it whenever Node.js or Debian publish security fixes: nothing here
# updates by itself, and a running install gets them only from a new image.

# Node.js comes from the official image, pinned to a patched LTS release.
# Debian stable ships Node.js 20, which is past its end of life upstream.
FROM node:24.22.1-trixie-slim AS node

FROM debian:stable-slim

# `upgrade` brings the packages already in debian:stable-slim up to date
# with Debian's security fixes, not only the ones installed here.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        supervisor redis-server wget gnupg lsb-release ca-certificates

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
    node --version && npm --version

# PostgreSQL 17 from the official apt repo
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg && \
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-17

ENV PATH="/usr/lib/postgresql/17/bin:$PATH"

LABEL org.opencontainers.image.source="https://github.com/PayRam/payram-runtime-base"
LABEL org.opencontainers.image.description="Runtime base for PayRam: postgres-17, redis, supervisor, node 24"
LABEL org.opencontainers.image.licenses="MIT"
