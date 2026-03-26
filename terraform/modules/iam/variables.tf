variable "project_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_location" {
  type = string
}

variable "kubernetes_namespace" {
  type    = string
  default = "default"
}

variable "kubernetes_sa_name" {
  type    = string
  default = "payment-api"
}

variable "secret_id" {
  description = "Secret Manager secret ID to grant access to"
  type        = string
}
