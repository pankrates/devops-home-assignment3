# ---------- Google Service Account ----------
resource "google_service_account" "payment_api" {
  account_id   = "payment-api-sa"
  display_name = "Payment API Service Account"
  project      = var.project_id
}

# ---------- Secret Manager access — scoped to ONE secret only ----------
resource "google_secret_manager_secret_iam_member" "secret_access" {
  project   = var.project_id
  secret_id = var.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.payment_api.email}"
}

# ---------- Workload Identity binding: KSA → GSA ----------
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.payment_api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_namespace}/${var.kubernetes_sa_name}]"
}
