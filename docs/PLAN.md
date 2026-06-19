# Project Plan — ChatDev Image & Helm Chart

Containerize [OpenBMB/ChatDev](https://github.com/OpenBMB/ChatDev) (the "DevAll"
2.x line) and ship a well-documented Helm chart. Upstream provides only a
dev-oriented Docker setup (bind mounts, Vite dev server) and no published images
or chart.

## Locked decisions

| # | Decision | Choice |
|---|----------|--------|
| 1 | Image registry | Docker Hub namespace `guidedtraffic` (`chatdev-backend`, `chatdev-frontend`) |
| 2 | LLM access | External API only; `BASE_URL` is a values knob (can point at any OpenAI-compatible endpoint, incl. in-cluster Ollama) |
| 3 | Exposure | **Single-host** ingress + TLS via cert-manager (see Architecture) |
| 4 | Build & release | GitHub Actions, mandatory — authoritative builds run in CI, never by hand |
| 5 | Chart distribution | GitHub Pages Helm repo (`chart-releaser-action`) |
| 6 | Upstream sourcing | Pinned clone in CI (`CHATDEV_REF`, default `v2.2.0`); this repo holds only overlays |
| 7 | Versioning | semver git tag `vX.Y.Z` → image tags + chart `version`; chart `appVersion` tracks the ChatDev ref |

GitHub org is `guided-traffic` (hyphen); Docker Hub namespace is `guidedtraffic`
(no hyphen). They are intentionally different.

## Architecture

ChatDev 2.x is a small multi-service app:

- **Backend** — FastAPI/uvicorn (`server.app:app`), port `6400`. No database,
  no auth. All state is on the filesystem under `/app`: `WareHouse/` (generated
  software artifacts), `logs/`, `schema_registry/`, plus mem0/faiss local
  indexes. Effectively a **singleton** → 1 replica + a ReadWriteOnce PVC.
- **Frontend** — Vue 3 + Vite SPA, served as static assets by nginx.

### Why single-origin

The frontend's HTTP client (`src/utils/apiFunctions.js`) is literally
`const apiUrl = (path) => path` — every API request is a **same-origin relative**
call to `/api/...`, and the WebSocket connects to `/ws` on
`window.location.host`. There is no way to redirect HTTP to a different host
without a proxy. So the only correct topology is a single origin where:

```
                         ┌────────────────────────── Ingress (one host, TLS) ──┐
  https://chatdev.example.com/        →  frontend Service (nginx, static SPA)
  https://chatdev.example.com/api     →  backend Service  (FastAPI :6400)
  https://chatdev.example.com/ws      →  backend Service  (WebSocket upgrade)
```

Consequences: no CORS configuration needed; the frontend image carries **zero**
backend address (built with an empty `VITE_API_BASE_URL`); the ingress does all
the wiring. A two-host layout was rejected — it cannot work given the hardcoded
relative HTTP paths.

## Images (M1)

- **Backend**: reuse upstream's multi-stage `Dockerfile` (`runtime` target) as-is
  — it is already production-shaped (slim base, prebuilt venv, non-root
  `appuser`, port 6400). No overlay needed; CI builds it from the pinned clone.
- **Frontend**: upstream ships only a dev Dockerfile, so this repo provides a
  production one ([images/frontend/](../images/frontend/)): Node build → static
  `dist` → unprivileged nginx (uid 101, port 8080, SPA history-mode fallback).

## Milestones

- **M1 — Images** ✅ done
  - Frontend production Dockerfile + nginx config — built & verified locally.
  - Backend image — built from pinned upstream (no overlay; runtime target).
  - `build-images.yml`: tag `v*` → build & push both to Docker Hub.
- **M2 — Helm chart** (`charts/chatdev`) ✅ done
  - Backend Deployment (1 replica, Recreate) + Service + PVC (`/app/WareHouse`).
  - Frontend Deployment + Service.
  - Single-host Ingress (path routing `/`, `/api`, `/ws` + WS timeouts), TLS via
    cert-manager annotation.
  - Secret (`API_KEY`, optional `SERPER_DEV_API_KEY`, `JINA_API_KEY`),
    ConfigMap (`BASE_URL`).
  - Probes, resources, non-root securityContext, sane `values.yaml`.
  - Verified end-to-end on kind: pods Ready, PVC bound, ingress routes `/`→FE,
    `/api`+`/ws`→BE, deep SPA routes → FE fallback.
- **M3 — Documentation** ✅ done
  - Chart README: full values table, install guide, provider examples
    (OpenAI / Ollama / Gemini), cert-manager prerequisite, architecture diagram.
- **M4 — Verification** 🟡 partial
  - kind deploy + ingress routing verified.
  - TODO: run a real ChatDev workflow against a live LLM, confirm artifacts land
    in the PVC (requires a real API key).
- **M5 — CI/CD release** ✅ done
  - Tag-driven image build/push (M1) + `release-chart.yml`
    (`chart-releaser-action` → GitHub Pages) + `lint-chart.yml` (PR validation).

## Prerequisites owned by the maintainer

- Docker Hub access token stored as repo secret `DOCKERHUB_PAT` (login user
  `guidedtraffic` is hardcoded in the build workflow env).
- GitHub Pages enabled on the repo (for the Helm chart repo).
