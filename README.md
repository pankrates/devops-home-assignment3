# Payment API — DevOps Home Assignment

## Architecture

```
GitHub Actions (CI/CD)
  │
  ├─ Build → Artifact Registry (Docker image)
  ├─ Scan  → Trivy (HIGH/CRITICAL gate) + hadolint
  └─ Deploy → Helm upgrade --install → GKE
                                         │
                              ┌──────────┴──────────┐
                              │   GKE (private)      │
                              │   ┌────────────────┐ │
                              │   │ payment-api pod │ │
                              │   │  (FastAPI)      │ │
                              │   │  KSA ──WI──▸ GSA│ │
                              │   └───────┬────────┘ │
                              └───────────┼──────────┘
                                          │
                    ┌─────────────────────┼─────────────────┐
                    ▼                     ▼                  ▼
             Secret Manager        Cloud Trace        Cloud Logging
             (payment-api-key)     (OpenTelemetry)    (structured JSON)
```

- **VPC**: Private VPC with two subnets (dev, staging), secondary ranges for pods/services, Cloud NAT, Private Google Access.
- **GKE**: Private cluster (no public node IPs), release channel REGULAR, Workload Identity enabled.
- **IAM**: GSA `payment-api-sa` with `secretmanager.secretAccessor` scoped to one secret only. KSA bound to GSA via Workload Identity.
- **CI/CD**: GitHub Actions with Workload Identity Federation (no SA keys). Auto rollback on deploy failure.

## Prerequisites

- GCP project with billing enabled
- `gcloud`, `terraform`, `helm`, `kubectl` installed
- Required GCP APIs are enabled automatically by Terraform (`google_project_service`)

## Terraform — Provision Infrastructure

### 1. Create the state bucket

```bash
gcloud storage buckets create gs://payment-api-tfstate-PROJECT_ID \
  --project=PROJECT_ID --location=us-central1
```

### 2. Initialize and apply

```bash
cd terraform

# Copy example vars and fill in your project ID
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values

terraform init
terraform plan
terraform apply
```

### 3. Add the secret value (outside Terraform — keeps it out of state)

```bash
echo -n "your-actual-secret-value" | \
  gcloud secrets versions add payment-api-key --data-file=- --project=PROJECT_ID
```

### Module layout

```
terraform/
├── backend.tf              # GCS remote state
├── main.tf                 # Root module — wires vpc, gke, iam, secrets + observability
├── variables.tf            # Input variables
├── terraform.tfvars.example
└── modules/
    ├── vpc/                # VPC, subnets, Cloud NAT
    ├── gke/                # Private GKE cluster
    ├── iam/                # GSA + Workload Identity binding
    └── secrets/            # Secret Manager secret (shell only)
```

## Workload Identity Binding

The Terraform IAM module creates:
1. **GSA** `payment-api-sa@PROJECT.iam.gserviceaccount.com`
2. **IAM binding**: GSA → `roles/secretmanager.secretAccessor` on the specific secret `payment-api-key`
3. **Workload Identity binding**: KSA `payment-api` in namespace `payment-api` → GSA

The Helm chart annotates the KSA with `iam.gke.io/gcp-service-account: <GSA email>`, completing the binding. The app reads the secret at startup using the default credentials provided by Workload Identity.

## CI/CD Pipeline

### Trigger

Push to `main` branch or manually via **Actions → Build and Deploy → Run workflow**.

### Required GitHub repository variables

| Variable | Description |
|----------|-------------|
| `WIF_PROVIDER` | Workload Identity Federation provider (e.g. `projects/123/locations/global/workloadIdentityPools/github/providers/github`) |
| `WIF_SERVICE_ACCOUNT` | GCP service account email for CI/CD (needs Artifact Registry writer + GKE developer + Connect Gateway roles) |
| `GCP_PROJECT_ID` | GCP project ID |
| `GCP_REGION` | GCP region (e.g. `us-central1`) |

### Pipeline jobs

1. **lint** — hadolint on `app/Dockerfile`
2. **build** — Build Docker image, Trivy scan (fails on HIGH/CRITICAL), push to Artifact Registry
3. **deploy** — `helm upgrade --install` to GKE; on failure → `helm rollback` automatically

### Setting up Workload Identity Federation for GitHub Actions

```bash
# Create workload identity pool
gcloud iam workload-identity-pools create github \
  --project=PROJECT_ID --location=global \
  --display-name="GitHub Actions"

# Create provider
gcloud iam workload-identity-pools providers create-oidc github \
  --project=PROJECT_ID --location=global \
  --workload-identity-pool=github \
  --display-name="GitHub" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Create CI/CD service account and grant roles
gcloud iam service-accounts create github-actions-sa --project=PROJECT_ID
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.developer"
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/gkehub.gatewayEditor"
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/gkehub.viewer"

# Allow GitHub repo to impersonate the SA
gcloud iam service-accounts add-iam-policy-binding \
  github-actions-sa@PROJECT_ID.iam.gserviceaccount.com \
  --project=PROJECT_ID \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUM/locations/global/workloadIdentityPools/github/attribute.repository/pankrates/devops-home-assignment3"
```

## Observability

### Logging

Application emits structured JSON logs to stdout, automatically collected by Cloud Logging.

**Cloud Logging filter** (paste into Logs Explorer):

```
resource.type="k8s_container"
resource.labels.project_id="YOUR_PROJECT_ID"
resource.labels.cluster_name="payment-api-cluster"
resource.labels.namespace_name="payment-api"
resource.labels.container_name="payment-api"
```

### Tracing

The app uses **OpenTelemetry** with the **Cloud Trace exporter**. Every incoming HTTP request is automatically traced via `opentelemetry-instrumentation-fastapi`.

**To view traces:**
1. Go to GCP Console → **Trace** (Cloud Trace)
2. Filter by service name `payment-api`
3. Click any trace to see the span timeline

### Health checks and alerting

- **Uptime check**: `payment-api-health` — pings `/health` every 60s (defined in Terraform)
- **Alert policy**: `Payment API Health Check Failure` — fires when the uptime check fails for 5 minutes, sends email notification

## Runbook

See [docs/runbook.md](docs/runbook.md) for the "API returns 5xx" runbook.

## Trade-offs and future improvements

- **Release channel REGULAR**: Balances stability with getting patches. In production, might use STABLE for critical workloads.
- **Rollback strategy**: Helm rollback to previous release. Could add canary deployments or progressive delivery (Flagger/Argo Rollouts) with more time.
- **Tracing backend**: Cloud Trace (managed) chosen over self-hosted Jaeger for simplicity. In a larger system, an OpenTelemetry Collector would allow routing to multiple backends.
- **Single region**: No multi-region or DR. Would add multi-region GKE with global load balancing for production.
- **Node pool**: Standard (non-preemptible) e2-medium nodes. In production, consider spot VMs with proper PDB for cost savings, or larger machine types for heavier workloads.
