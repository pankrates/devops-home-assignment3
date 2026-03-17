# Runbook: API returns 5xx

> **Candidate:** Replace this stub with your runbook. Required:
> - 3–5 concrete steps (exact Cloud Logging filter, exact metric/chart names in Cloud Monitoring, what to check in GKE: pod status, events, recent rollout).
> - One escalation or remediation hint (e.g. if pods are CrashLoopBackOff, check Secret Manager access and Workload Identity).

## 1. Check pod status

```bash
kubectl get pods -l app=payment-api -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
```

## 2. Check logs

(Add exact Cloud Logging filter here, e.g. `resource.type="k8s_container"`, `resource.labels.container_name="payment-api"`.)

## 3. Check metrics and alerts

(Add exact metric names and where to view in Cloud Monitoring.)

## 4. Recent rollout

```bash
kubectl rollout history deployment/payment-api -n <namespace>
```

## 5. Escalation / remediation

(Add hint, e.g. CrashLoopBackOff → verify Secret Manager and Workload Identity.)
