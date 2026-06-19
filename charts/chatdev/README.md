# ChatDev Helm Chart

Deploys [OpenBMB/ChatDev](https://github.com/OpenBMB/ChatDev) (the "DevAll" 2.x
line) — a multi-agent, LLM-driven software-development team — onto Kubernetes:
the FastAPI backend and the Vue SPA frontend behind a single ingress host.

- **Images:** `guidedtraffic/chatdev-backend`, `guidedtraffic/chatdev-frontend`
- **Upstream version:** see `appVersion` in [Chart.yaml](Chart.yaml)

## TL;DR

```sh
helm repo add chatdev https://guided-traffic.github.io/chatdev-helm-chart
helm repo update

helm install chatdev chatdev/chatdev \
  --namespace chatdev --create-namespace \
  --set secrets.apiKey=sk-your-openai-key \
  --set ingress.host=chatdev.example.com \
  --set ingress.tls.clusterIssuer=letsencrypt-prod
```

Then open `https://chatdev.example.com/`.

## Architecture

ChatDev's SPA talks to its backend with **same-origin relative paths** (`/api`,
`/ws`) — there is no client-side base-URL setting. The chart therefore puts both
services behind **one ingress host** and routes by path:

```
                         Ingress (one host, TLS via cert-manager)
   https://<host>/        ─────────────►  frontend Service  (nginx static SPA, :8080)
   https://<host>/api     ─────────────►  backend Service   (FastAPI,        :6400)
   https://<host>/ws      ─────────────►  backend Service   (WebSocket upgrade)
```

No CORS configuration is needed, and the frontend image contains no backend
address. A two-host layout is **not** supported — it cannot work with the
hardcoded relative paths.

The backend stores all state on disk under `/app` (generated software in
`WareHouse/`, plus logs and local indexes) and has no database. It is a
**singleton**: keep `backend.replicaCount` at `1`, backed by a ReadWriteOnce
PVC and a `Recreate` rollout.

## Prerequisites

- Kubernetes 1.23+ and Helm 3.8+
- An ingress controller. Defaults target **ingress-nginx**
  (`ingress.className: nginx`) with WebSocket-friendly proxy timeouts in
  `ingress.annotations`. For other controllers, set `ingress.className` and
  replace `ingress.annotations` (see [Other ingress controllers](#other-ingress-controllers)).
- A StorageClass for the backend PVC. If the cluster has **no default
  StorageClass**, set `backend.persistence.storageClass` explicitly (e.g.
  `--set backend.persistence.storageClass=nvme-r2-ext4`), otherwise the PVC
  stays Pending.
- For automatic TLS: [cert-manager](https://cert-manager.io) with a
  ClusterIssuer. Set `ingress.tls.clusterIssuer`. Otherwise provide the TLS
  secret yourself, or disable TLS for local testing.
- An OpenAI-compatible LLM endpoint + API key (or any compatible service such
  as an in-cluster Ollama).

## Configuration

### Secrets (LLM keys)

Provide the key inline (the chart creates a Secret):

```sh
--set secrets.apiKey=sk-...
--set secrets.serperDevApiKey=...   # optional: web search (serper.dev)
--set secrets.jinaApiKey=...        # optional: web reading (jina.ai)
```

…or reference an existing Secret containing `API_KEY` (and optionally
`SERPER_DEV_API_KEY`, `JINA_API_KEY`):

```sh
--set secrets.existingSecret=my-chatdev-secret
```

### LLM provider examples

OpenAI (default):

```yaml
config:
  baseUrl: "https://api.openai.com/v1"
secrets:
  apiKey: "sk-..."
```

In-cluster Ollama (no external API):

```yaml
config:
  baseUrl: "http://ollama.ollama.svc.cluster.local:11434/v1"
secrets:
  apiKey: "ollama"   # any non-empty placeholder
```

Google Gemini (OpenAI-compatible endpoint):

```yaml
config:
  baseUrl: "https://generativelanguage.googleapis.com/v1beta/openai"
secrets:
  apiKey: "..."
```

### Persistence

Generated software and on-disk state are kept on a PVC mounted at
`/app/WareHouse`:

```yaml
backend:
  persistence:
    enabled: true        # set false to use an ephemeral emptyDir
    size: 5Gi
    storageClass: ""     # "" = cluster default
    accessMode: ReadWriteOnce
    existingClaim: ""    # bring your own PVC
```

## Values reference

| Key | Default | Description |
|-----|---------|-------------|
| `nameOverride` / `fullnameOverride` | `""` | Override generated names. |
| `imagePullSecrets` | `[]` | Pull secrets for private registries. |
| `config.baseUrl` | `https://api.openai.com/v1` | OpenAI-compatible LLM endpoint (`BASE_URL`). |
| `config.extraEnv` | `[]` | Extra non-secret env vars for the backend. |
| `secrets.existingSecret` | `""` | Use an existing Secret instead of creating one. |
| `secrets.apiKey` | `""` | LLM API key (`API_KEY`). Required unless `existingSecret`. |
| `secrets.serperDevApiKey` | `""` | Optional serper.dev key. |
| `secrets.jinaApiKey` | `""` | Optional jina.ai key. |
| `backend.replicaCount` | `1` | Keep at 1 (stateful singleton). |
| `backend.image.repository` | `guidedtraffic/chatdev-backend` | Backend image. |
| `backend.image.tag` | `""` | Defaults to the chart version. |
| `backend.image.pullPolicy` | `IfNotPresent` | |
| `backend.service.type` / `.port` | `ClusterIP` / `6400` | |
| `backend.resources` | requests 250m/512Mi, limit 2Gi | Tune to workload. |
| `backend.persistence.*` | see above | WareHouse PVC. |
| `backend.podSecurityContext.fsGroup` | `1000` | Makes the PVC writable by the image user. |
| `backend.securityContext` | non-root uid 1000, no privesc, drop ALL caps | |
| `backend.probes.*` | startup/readiness on `/docs`, liveness TCP | |
| `backend.nodeSelector` / `tolerations` / `affinity` | `{}` / `[]` / `{}` | Scheduling. |
| `frontend.replicaCount` | `1` | Stateless; safe to scale up. |
| `frontend.image.repository` | `guidedtraffic/chatdev-frontend` | Frontend image. |
| `frontend.image.tag` | `""` | Defaults to the chart version. |
| `frontend.service.type` / `.port` | `ClusterIP` / `8080` | |
| `frontend.resources` | requests 10m/32Mi, limit 128Mi | |
| `frontend.securityContext` | non-root uid 101, no privesc, drop ALL caps | |
| `ingress.enabled` | `true` | |
| `ingress.className` | `nginx` | Ingress class (e.g. `nginx`, `traefik`, `hpi-internal`). |
| `ingress.host` | `chatdev.example.com` | The single host serving SPA + API. |
| `ingress.annotations` | nginx WS proxy timeouts | Controller-specific annotations; replace for non-nginx controllers. |
| `ingress.tls.enabled` | `true` | Add a TLS block to the ingress. |
| `ingress.tls.clusterIssuer` | `""` | cert-manager ClusterIssuer (adds the annotation). |
| `ingress.tls.secretName` | `""` | Defaults to `<release>-tls`. |
| `ingress.backendPaths` | `[/api, /ws]` | Path prefixes routed to the backend. |

## Other ingress controllers

The defaults target ingress-nginx. For a different controller, set
`ingress.className` and replace `ingress.annotations` with the equivalents.
Path routing (`/`, `/api`, `/ws`) and WebSocket support are otherwise the same.

HAProxy ingress example:

```yaml
ingress:
  className: hpi-internal      # or hpi-external
  host: chatdev.example.com
  annotations:
    haproxy-ingress.github.io/timeout-client: 1h
    haproxy-ingress.github.io/timeout-server: 1h
  tls:
    clusterIssuer: letsencrypt-prod
```

To emit an ingress with no annotations at all, set `ingress.annotations: {}`
(the cert-manager annotation is still added when `ingress.tls.clusterIssuer`
is set).

## Local testing (kind)

Build the images locally, load them into kind, install with the bundled CI
values, and verify path routing — see the repository
[README](../../README.md) and `ci/kind-values.yaml`.

## Notes

- `helm install` fails fast if neither `secrets.apiKey` nor
  `secrets.existingSecret` is set.
- With `ingress.enabled=false` the SPA cannot reach the backend (it needs a
  shared origin); use ingress for anything beyond a smoke test.
