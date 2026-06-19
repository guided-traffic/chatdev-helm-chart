# ChatDev — Container Images & Helm Chart

Production container images and a Helm chart for
[OpenBMB/ChatDev](https://github.com/OpenBMB/ChatDev) (the "DevAll" 2.x line), a
multi-agent software-development team driven by LLMs.

Upstream ships only a dev-oriented Docker setup (bind mounts, Vite dev server)
and publishes no images or chart. This repository provides:

- a **production frontend image** (static SPA on nginx),
- a thin reuse of upstream's already-production-shaped **backend image**,
- a **Helm chart** (work in progress),
- **GitHub Actions** that build and release everything.

This repo holds only overlays and packaging — the ChatDev source is cloned at a
pinned ref (`CHATDEV_REF`, default `v2.2.0`) during the build.

See [docs/PLAN.md](docs/PLAN.md) for the full design, decisions, and roadmap.

## Status

| Milestone | State |
|-----------|-------|
| M1 — Images + CI build | ✅ Images built & smoke-tested locally; build/push workflow added |
| M2 — Helm chart | ✅ Chart written; deployed & verified end-to-end on kind |
| M3 — Documentation | ✅ Chart [README](charts/chatdev/README.md) with values table, provider & TLS examples |
| M4 — Verification | 🟡 kind deploy + ingress routing verified; real LLM workflow run pending (needs an API key) |
| M5 — Chart release (GH Pages) | ✅ `chart-releaser` + lint workflows added (needs one-time repo setup below) |

## Repository setup (one-time)

Before CI can build/release:

1. **Docker Hub** — create an access token and add it as the repo secret
   `DOCKERHUB_PAT`. The login user is the `guidedtraffic` Docker ID (set in the
   workflow env).
2. **GitHub Pages Helm repo** — create an empty `gh-pages` branch and enable
   GitHub Pages on it. The chart then publishes to
   `https://guided-traffic.github.io/chatdev-helm-chart`.

Release flow: tag `vX.Y.Z` builds and pushes the images; pushing a
`charts/chatdev/Chart.yaml` `version` bump to `main` publishes the chart.

## Images

Published to Docker Hub namespace `guidedtraffic`:

| Image | Source | Port | User |
|-------|--------|------|------|
| `guidedtraffic/chatdev-backend` | upstream `Dockerfile` (`runtime` target), as-is | 6400 | `appuser` (1000) |
| `guidedtraffic/chatdev-frontend` | [images/frontend/](images/frontend/) (this repo) | 8080 | `nginx` (101) |

### Architecture (single origin)

The frontend calls the backend with same-origin relative paths (`/api`, `/ws`),
so both must share one origin. The Helm chart's ingress routes `/` to the
frontend and `/api` + `/ws` to the backend on a single host — no CORS, and the
frontend image carries no backend address. Details in
[docs/PLAN.md](docs/PLAN.md#architecture).

## Building locally

Mirrors the CI build (shallow-clones the pinned upstream, builds both images, no
push):

```sh
scripts/build-local.sh            # uses default ref v2.2.0
scripts/build-local.sh v2.2.0     # or pin explicitly
```

Smoke-test the result:

```sh
# Frontend: static SPA on :8080
docker run --rm -p 8080:8080 chatdev-frontend:local

# Backend: FastAPI on :6400 (API_KEY/BASE_URL only needed to actually run agents)
docker run --rm -p 6400:6400 -e API_KEY=sk-... -e BASE_URL=https://api.openai.com/v1 \
  chatdev-backend:local
# then: open http://localhost:6400/docs
```

## CI / Release

`.github/workflows/build-images.yml` builds and pushes both images to Docker Hub
on a `v*` git tag (or via manual dispatch with a chosen upstream ref).

**Required repo secret:** `DOCKERHUB_PAT` (login user `guidedtraffic` is set in
the workflow env).
