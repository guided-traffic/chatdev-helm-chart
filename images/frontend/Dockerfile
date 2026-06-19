# Production image for the ChatDev (DevAll) Vue/Vite frontend.
#
# Upstream only ships a dev Dockerfile (vite dev server). This builds the SPA
# to static assets and serves them with an unprivileged nginx.
#
# Build context MUST be ChatDev's `frontend/` directory. CI copies this file
# and nginx.conf into that directory before building.
#
# The SPA's HTTP client (src/utils/apiFunctions.js: `apiUrl = path => path`)
# always calls the backend same-origin via relative /api and /ws paths. So the
# image carries NO backend address: the Helm chart's ingress routes /api and
# /ws to the backend and / to this frontend on a single host. We build with an
# empty VITE_API_BASE_URL so the WebSocket client also stays same-origin.

# ---- deps: install node_modules once (cached) ----
FROM node:24-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --no-audit --no-fund || npm install --no-audit --no-fund

# ---- build: compile static assets ----
FROM node:24-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV VITE_API_BASE_URL=""
RUN npm run build

# ---- runtime: unprivileged nginx (uid 101, listens on 8080) ----
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime
COPY --chown=101:101 nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build --chown=101:101 /app/dist /usr/share/nginx/html
EXPOSE 8080
