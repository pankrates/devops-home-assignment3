variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "secondary_range_pods" {
  type = string
}

variable "secondary_range_services" {
  type = string
}

variable "node_locations" {
  description = "Zones for GKE nodes. Use this to exclude zones with capacity issues (e.g. us-central1-b)."
  type        = list(string)
  default     = []
}
