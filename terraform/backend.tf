terraform {
  backend "gcs" {
    bucket = "payment-api-tfstate-homework-yp"
    prefix = "payment-api/state"
  }
}
