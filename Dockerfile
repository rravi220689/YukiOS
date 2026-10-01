# Multi-stage build: build with pnpm and serve static output with nginx
# This Dockerfile is adapted to the repository layout where the app lives in the
# `webos-desktop/` subdirectory. Build context should be the repository root.

FROM node:22-bookworm AS builder

# Build inside subdirectory so COPY paths match project layout
WORKDIR /app/webos-desktop

# Use Corepack to enable pnpm and ensure latest pnpm is available
RUN corepack enable && corepack prepare pnpm@latest --activate

# Prevent Electron from downloading prebuilt binaries during web build
ENV ELECTRON_SKIP_BINARY_DOWNLOAD=1
ENV PNPM_FETCH_TIMEOUT=600000

# Copy package manifest, lockfile, and workspace config from the subdirectory to leverage Docker layer caching
COPY webos-desktop/package.json webos-desktop/pnpm-lock.yaml webos-desktop/pnpm-workspace.yaml* ./

# Install dependencies with increased timeout and fallback
RUN pnpm config set fetch-timeout 600000 && \
    pnpm config set fetch-retries 5 && \
    (pnpm install --frozen-lockfile || pnpm install)

# Copy app source and root assets needed during build (e.g., ../README.md and ../static)
WORKDIR /app
COPY . .

WORKDIR /app/webos-desktop

# Allow projects that use either `build` or `build:dev` script
ARG BUILD_OUTPUT=dist
RUN pnpm run build || pnpm run build:dev

# Production image: nginx serving static files
FROM nginx:alpine

# Replace default nginx config (nginx.conf is at repository root)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy build output from builder stage
COPY --from=builder /app/webos-desktop/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
