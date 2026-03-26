variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "payment-api-cluster"
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "payment-api-vpc"
}

variable "alert_email" {
  description = "Email for alert notifications"
  type        = string
  default     = "devops@example.com"
}

variable "node_locations" {
  description = "Zones for GKE nodes. Exclude zones with GCE_STOCKOUT issues (e.g. set to [\"us-central1-a\", \"us-central1-c\"] to skip zone b)."
  type        = list(string)
  default     = ["us-central1-a", "us-central1-c"]
}
