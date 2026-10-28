# Hearth on Kubernetes

A second way to run Hearth, beside Docker Compose. One Helm chart in `hearth/` runs the API release in pools by role and the web server. Secrets come from HashiCorp Vault.

```
infra/k8s/
├── hearth/                     # The Helm chart
│   ├── Chart.yaml
│   ├── values.yaml             # Defaults for every environment
│   ├── values.staging.yaml     # What staging changes
│   ├── values.production.yaml  # What production changes
│   ├── files/secrets.yml       # Which variables come from Vault, and where
│   └── templates/
└── vault/
    ├── policy.hcl              # Read only access to one environment
    └── setup.sh                # Mount, policy and auth roles for an environment
```

## Commands

```sh
make k8s.lint                          # helm lint with each environment's values
make k8s.render ENV=production         # the manifests, printed, no cluster needed
make k8s.apply ENV=staging             # helm upgrade --install --atomic in the current context
```

`NAMESPACE` (default `hearth`) and `RELEASE` (default `hearth`) pick where it goes. `k8s.apply` waits for the new pods to be ready and rolls back if they never are.

## What runs

| Deployment | `HEARTH_ROLES` | Why it's apart |
| --- | --- | --- |
| `api-web` | `web` | The API, sockets and default jobs. It runs `bin/migrate` as an init container, scales on CPU and sits behind the Ingress |
| `api-media` | `media` | libvips and ffmpeg use every core they get, so a big upload never slows the API |
| `api-ai` | `ai` | Local screening loads its models once, about 3 GB together. Their weights live on a volume (`pools.ai.modelCache`) so a restart doesn't download them again |
| `api-rtc` | `rtc` | Off until voice rooms ship. Uses the node's network, one pod per node, see below |
| `web` | | The React Router server for public screens. It calls the API on the cluster network |
| `coturn` | | Optional TURN relay for voice, on the node's network |

Every API pool is the same image. All of them join one Erlang cluster through a headless Service (`<release>-cluster`), which `DNSCluster` queries. Each pod names itself `hearth@<pod ip>`, and the cookie is a Secret the chart makes once and keeps across upgrades.

Each pod starts only what its `HEARTH_ROLES` name. Every pod joins the cluster and runs the repo, PubSub, Oban and the metrics port. Oban fetches only the queues of the pod's roles, so a media job waits for a media pod and never runs on a web pod. Only `web` pods run the public endpoint, the listeners and the buffered writers, and only `ai` pods load the screening models. Jobs on any pod raise socket events, which reach the browsers on web pods through the cluster.

Probes use `/healthz/live` for liveness and startup, and `/healthz/ready` (which checks the database) for readiness. Web pods answer them on the API port. Other pods have no public endpoint, so they answer the same paths on the metrics port, ahead of its basic auth. The ai pool gets ten minutes to start, for its first model download. Deployments add a new pod before taking an old one away, and each pool has a PodDisruptionBudget, so a release or a node drain never drops below the running count.

Pods run as uid 1000 with a read only root filesystem, no privilege escalation and every capability dropped. `/tmp` is an `emptyDir` for the release's scratch files.

**Routing.** The Ingress sends `/api`, `/socket`, `/webhooks`, `/robots.txt`, `/sitemap.xml`, `/sitemaps`, `/og`, `/storage` and `/healthz` to the API, and everything else to the web server, the same split Caddy makes. cert-manager issues the certificate through the `cert-manager.io/cluster-issuer` annotation. Set `httpRoute.enabled` (and `ingress.enabled: false`) to use the Gateway API instead.

**Voice.** Browsers send WebRTC media straight to the node that holds their peer connection, over a range of UDP ports. A Service would have to publish 200 UDP ports per node and hide the node's own address from the SFU, so `api-rtc` pods use `hostNetwork` instead, one per node (anti-affinity), and bind `RTC_PORT_RANGE` on the node itself. Open that range in the node's firewall and set `RTC_PUBLIC_IP` when nodes sit behind NAT. coturn runs the same way for people on networks that block UDP. Label the nodes for voice and point `pools.rtc.nodeSelector` at them, as `values.production.yaml` does.

**Metrics.** PromEx answers on port 9568 of every API pod, through the `<release>-metrics` Service. It carries `prometheus.io/*` annotations, and `metrics.serviceMonitor.enabled` adds a ServiceMonitor for the Prometheus Operator, with basic auth from a Secret when `METRICS_USERNAME` and `METRICS_PASSWORD` are set.

**Postgres and object storage** are outside the cluster by default. Point `DATABASE_URL` at your database and the `S3_*` settings at your store. Local file storage needs a disk every API pod can share, so the chart sets `STORAGE: s3`. For a full self host:

- `postgres.cnpg.enabled` adds a CloudNativePG `Cluster`. Install the operator first. It writes the connection string to the `<fullname>-postgres-app` Secret (`hearth-postgres-app` for a release named hearth), which you copy into Vault as `database url`.
- `objectStorage.seaweedfs.enabled` adds one SeaweedFS node with its S3 gateway on port 8333. Give it an `s3.json` with your keys in `objectStorage.seaweedfs.existingSecret`, then set `S3_ENDPOINT` to `http://<fullname>-s3:8333` and `S3_PATH_STYLE` to `true`. MinIO's community edition stopped publishing images in 2025 and has since been archived, so it isn't offered.

## Secrets

The release reads its own secrets from Vault at boot, so nothing secret is stored in Kubernetes apart from the Erlang cookie. There is no Vault Agent sidecar.

1. `files/secrets.yml` maps each variable to a KV v2 path and key, such as `DATABASE_URL` to `hearth/{env}/database` `url`. The chart mounts it at `/etc/hearth/secrets.yml` and sets `SECRETS_FILE`, `SECRETS_ENV`, `VAULT_ADDR`, `VAULT_AUTH` and `VAULT_ROLE`.
2. The first thing `config/runtime.exs` does is call `Secrets.inject!/0`. It signs in to Vault with the pod's service account token (`VAULT_AUTH=kubernetes`), reads each secret once, and sets every variable before the rest of `runtime.exs` or any app reads one. The same happens in the `migrate` init container.
3. A missing value stops the pod at boot with the variable's name, unless its line says `optional: true`, which leaves that feature off. Nothing is set until every value is read. Values are never logged, and the token and secret structs leave them out of inspect output.

The first segment of each path is the KV v2 mount, so `hearth/production/database` is read from `/v1/hearth/data/production/database`.

**Setting up Vault for an environment.**

```sh
# Mount, policy and the Kubernetes auth role bound to the chart's service account.
ENV=production NAMESPACE=hearth ./vault/setup.sh

# The values themselves, one secret per group. Leave out what you don't use.
vault kv put hearth/production/database url='ecto://hearth:...@db:5432/hearth'
vault kv put hearth/production/app secret_key_base=... jwt_private_key=@jwt.pem
vault kv put hearth/production/encryption key=... hash_key=...
vault kv put hearth/production/storage access_key_id=... secret_access_key=...
vault kv put hearth/production/mail postmark_api_key=...
```

`setup.sh` needs `KUBERNETES_HOST` when Vault runs outside the cluster. The Kubernetes auth role is bound to the `hearth` service account in the release's namespace and grants a 15 minute token with read only access to `hearth/<env>/*`.

**Without Vault.** Set `secrets.source: kubernetes` and `secrets.existingSecret` to a Secret whose keys are the variable names. Every key becomes a variable.

**Compose with Vault.** `infra/compose.vault.yml` turns the same reading on for the Compose setup, signing in with an AppRole whose role id and secret id sit in `infra/vault-role-id` and `infra/vault-secret-id` (gitignored). `APPROLE=1 ./vault/setup.sh` makes the role.

```sh
docker compose -f infra/compose.yml -f infra/compose.vault.yml up --detach
```

## Trying it

`make k8s.render ENV=staging` prints everything the chart would create, without a cluster. On a local cluster (kind or k3d), build both images, load them into the cluster, and install with a Vault dev server or `secrets.source: kubernetes`.

```sh
docker build -f infra/docker/api.Dockerfile -t ghcr.io/daniel-brai/hearth-api:dev .
docker build -f infra/docker/web.Dockerfile -t ghcr.io/daniel-brai/hearth-web:dev .
kind load docker-image ghcr.io/daniel-brai/hearth-api:dev ghcr.io/daniel-brai/hearth-web:dev
helm upgrade --install hearth infra/k8s/hearth -n hearth --create-namespace \
  -f infra/k8s/hearth/values.staging.yaml \
  --set images.api.tag=dev --set images.web.tag=dev \
  --set secrets.source=kubernetes --set secrets.existingSecret=hearth-env
```

## Why Helm

One chart with a values file per environment keeps what differs between staging and production in one short file each. The optional pieces (voice, coturn, CloudNativePG, SeaweedFS, the Gateway API, the ServiceMonitor) are flags rather than overlays, and `helm upgrade --atomic` rolls a failed release back by itself. The optional pieces are templates in this chart, not subchart dependencies, so `helm lint` and `helm template` work offline with nothing to download.
