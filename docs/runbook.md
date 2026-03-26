# Runbook: API returns 5xx

## 1. Check pod status

```bash
kubectl get pods -l app=payment-api -n payment-api
kubectl describe pod <pod-name> -n payment-api
kubectl get events -n payment-api --sort-by='.lastTimestamp' | head -20
```

Look for: `CrashLoopBackOff`, `ImagePullBackOff`, `OOMKilled`, or pending pods.

## 2. Check application logs in Cloud Logging

Open **Logs Explorer** in GCP Console and paste this filter:

```
resource.type="k8s_container"
resource.labels.project_id="YOUR_PROJECT_ID"
resource.labels.cluster_name="payment-api-cluster"
resource.labels.namespace_name="payment-api"
resource.labels.container_name="payment-api"
severity>=ERROR
```

For all logs (not just errors), remove the `severity>=ERROR` line.

To filter for 5xx responses specifically:

```
resource.type="k8s_container"
resource.labels.namespace_name="payment-api"
resource.labels.container_name="payment-api"
jsonPayload.status>=500
```

## 3. Check metrics and alerts in Cloud Monitoring

1. Go to **Monitoring → Alerting** — check if the **"Payment API Health Check Failure"** alert has fired.
2. Go to **Monitoring → Uptime Checks** — check the **"payment-api-health"** uptime check status.
3. Go to **Monitoring → Metrics Explorer** and query:
   - Metric: `monitoring.googleapis.com/uptime_check/check_passed`
   - Filter: `check_id = "payment-api-health"`

## 4. Check recent rollout

```bash
kubectl rollout status deployment/payment-api -n payment-api
kubectl rollout history deployment/payment-api -n payment-api
```

If the latest rollout is the cause, rollback:

```bash
helm rollback payment-api 0 -n payment-api --wait
```

## 5. Escalation / remediation

| Symptom | Action |
|---------|--------|
| **CrashLoopBackOff** | Check logs (step 2). Common cause: Secret Manager access failure — verify Workload Identity binding: `kubectl describe sa payment-api -n payment-api` should show annotation `iam.gke.io/gcp-service-account`. Verify GSA has `secretmanager.secretAccessor` on the secret. |
| **ImagePullBackOff** | Verify Artifact Registry image exists: `gcloud artifacts docker images list REGION-docker.pkg.dev/YOUR_PROJECT_ID/payment-api-repo/payment-api`. Check node SA has `artifactregistry.reader` role. |
| **OOMKilled** | Increase memory limits in Helm values and redeploy. |
| **Pods running but 5xx** | Check app logs for stack traces. Verify Secret Manager secret has a version: `gcloud secrets versions list payment-api-key`. Check Cloud Trace for slow/failed spans. |

**Escalation:** If unresolved after 15 minutes, escalate to the platform engineering team with: pod describe output, last 50 log lines, and recent rollout history.
