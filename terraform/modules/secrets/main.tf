# Creates the Secret Manager secret shell.
# The actual secret VALUE must be added outside Terraform:
#   gcloud secrets versions add payment-api-key --data-file=- <<< "your-secret-value"
# This keeps the secret out of code and Terraform state.

resource "google_secret_manager_secret" "secret" {
  project   = var.project_id
  secret_id = var.secret_id

  replication {
    auto {}
  }
}
