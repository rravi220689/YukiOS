# Multi-stage build: build with pnpm and serve static output with nginx
FROM node:20-bullseye AS builder

WORKDIR /app

# Use Corepack to enable pnpm and ensure latest pnpm is available
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy lockfiles and package manifest first to leverage Docker layer caching
COPY package.json pnpm-lock.yaml ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source
COPY . .

# Allow projects that use either `build` or `build:dev` script
ARG BUILD_OUTPUT=dist
RUN pnpm run build || pnpm run build:dev

# Production image: nginx serving static files
FROM nginx:alpine

# Replace default nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy build output from builder stage
COPY --from=builder /app/${BUILD_OUTPUT} /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
