# syntax=docker/dockerfile:1
#
# PayRam runtime base image
# -------------------------
# Rarely-changing foundation for the combined PayRam image.  Builds of
# payram-core start FROM this instead of reinstalling postgres / redis /
# nginx / supervisor on every build, shaving 1–2 minutes off every CI run.
#
# Bump the tag (v2.0.0 → v2.1.0) when you change anything here.
# Bump the MAJOR tag (v2 → v3) only for breaking changes that require
# payram-core to opt in (e.g., PostgreSQL or Node.js major-version upgrade).
#
# Rebuild it whenever Node.js, Debian, PostgreSQL, Redis or nginx publish
# security fixes: nothing here updates by itself, and a running install gets
# them only from a new image.

# Node.js comes from the official image, pinned to an exact release of the
# 26 line, which becomes LTS on 28 October 2026 (24 is in maintenance from
# 20 October). Debian stable ships Node.js 20, past its end of life.
FROM node:26.12.1-trixie-slim AS node

# Debian 13 by name: `stable` would jump to the next Debian release on its
# own the day it ships.
FROM debian:trixie-slim

# Signing keys of the vendor repositories, pinned by checksum so a changed key
# fails the build instead of being trusted silently. Fingerprints:
#   nginx    573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62, 8540A6F18833A80E9C1653A42FD21310B49F6B46
#   pgdg     B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8
#   redis    54318FA4052D1E61A6B6F7BB5F4349D6BF53AA0C
ADD --chmod=644 --checksum=sha256:55385da31d198fa6a5012d40ae98ecb272a6c4e8fffffba94719ffd3e87de37a \
    https://nginx.org/keys/nginx_signing.key /usr/share/keyrings/nginx.asc
ADD --chmod=644 --checksum=sha256:0144068502a1eddd2a0280ede10ef607d1ec592ce819940991203941564e8e76 \
    https://www.postgresql.org/media/keys/ACCC4CF8.asc /usr/share/keyrings/pgdg.asc
ADD --chmod=644 --checksum=sha256:817b5a78358d00ed6b71884d70ad5d2eab9934badca1a34299fdc6a2e4a8ad20 \
    https://packages.redis.io/gpg /usr/share/keyrings/redis.asc

# Each vendor's own repository, so the image gets their current releases
# rather than the versions Debian froze for trixie (nginx 1.26, Redis 8.0):
#   nginx       stable line, from nginx.org
#   PostgreSQL  17, from apt.postgresql.org (a new major needs pg_upgrade
#               for existing data, so it changes only with a new MAJOR tag)
#   Redis       latest release, from packages.redis.io
COPY <<EOF /etc/apt/sources.list.d/vendors.sources
Types: deb
URIs: https://nginx.org/packages/debian
Suites: trixie
Components: nginx
Signed-By: /usr/share/keyrings/nginx.asc

Types: deb
URIs: https://apt.postgresql.org/pub/repos/apt
Suites: trixie-pgdg
Components: main
Signed-By: /usr/share/keyrings/pgdg.asc

Types: deb
URIs: https://packages.redis.io/deb
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/redis.asc
EOF

# PayRam keeps its database in its own data directory (startup.sh), so the
# package's default cluster in /var/lib/postgresql/17/main is never used.
COPY <<EOF /etc/postgresql-common/createcluster.d/payram.conf
create_main_cluster = false
EOF

# `upgrade` brings the packages already in debian:trixie-slim up to date with
# Debian's security fixes, not only the ones installed here. The vendor
# repositories need ca-certificates for HTTPS, so it is installed first, with
# them switched off. wget is not used by the image itself: setup_payram.sh and
# the updater's installer check health with `docker exec payram wget`, and the
# copies already on merchants' servers expect it.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    mv /etc/apt/sources.list.d/vendors.sources /tmp/ && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    mv /tmp/vendors.sources /etc/apt/sources.list.d/ && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        libatomic1 libstdc++6 \
        supervisor \
        wget \
        nginx \
        gettext-base \
        redis-server \
        postgresql-17 && \
    # Redis's package loads its search, JSON, time-series and bloom-filter
    # modules. PayRam uses Redis as a plain cache, so they stay off: less
    # memory, less code listening. (Vector sets are built into Redis 8 and
    # always listed by MODULE LIST.)
    sed -i 's/^loadmodule /# loadmodule /' /etc/redis/redis.conf

# The Node.js binary needs libatomic1 and libstdc++6, installed above.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
    node --version && npm --version && nginx -v && redis-server --version && \
    /usr/lib/postgresql/17/bin/postgres --version

ENV PATH="/usr/lib/postgresql/17/bin:$PATH"

LABEL org.opencontainers.image.source="https://github.com/PayRam/payram-runtime-base"
LABEL org.opencontainers.image.description="Runtime base for PayRam: Debian 13, Node.js 26, PostgreSQL 17, Redis, nginx, supervisor"
LABEL org.opencontainers.image.licenses="MIT"
