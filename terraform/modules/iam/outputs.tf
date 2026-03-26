output "gsa_email" {
  value = google_service_account.payment_api.email
}

output "gsa_name" {
  value = google_service_account.payment_api.name
}
