# syntax=docker/dockerfile:1
FROM node:20-slim

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

COPY frontend/package.json /package.json
COPY frontend/yarn.lock /yarn.lock

# Install with cache mount for faster rebuilds
# it's not entirely clear what --modules-folder does. It probably works without.
# the general idea is that the /node_modules are outside the volume mount into /app which
# later happens (see docker-compose.yml -> frontend service)
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn \
    yarn install --pure-lockfile --modules-folder /node_modules --network-timeout 100000

# Set environment
ENV NODE_ENV=development
