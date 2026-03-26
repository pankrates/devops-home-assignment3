variable "project_id" {
  type = string
}

variable "secret_id" {
  description = "Secret name in Secret Manager"
  type        = string
  default     = "payment-api-key"
}
