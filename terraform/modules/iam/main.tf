# Stub: GCP service account for payment API with minimal permissions (e.g. Secret Manager secretAccessor).
# Workload Identity: Kubernetes SA -> GCP SA binding (google_service_account_iam_member for workloadIdentityUser).
# Output: GSA email for pipeline/Helm.

variable "project_id" { type = string }
variable "cluster_name" { type = string }
variable "cluster_location" { type = string }
variable "kubernetes_namespace" { type = string }
variable "kubernetes_sa_name" { type = string }

# Add: google_service_account, google_project_iam_member (secretmanager.secretAccessor), 
#      google_service_account_iam_member (workloadIdentityUser) for the K8s SA.
# Create K8s SA and annotate in Helm or separate manifest.

output "gsa_email" {
  value = "stub@${var.project_id}.iam.gserviceaccount.com"
}
