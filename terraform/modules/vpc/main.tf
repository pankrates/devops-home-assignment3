# Stub: VPC with secondary ranges for GKE (pods + services).
# Required: Private Google Access, at least two subnets.
# Output: network name, subnets, secondary ranges for use by GKE module.

variable "project_id" {
  type = string
}
variable "region" {
  type = string
}
variable "network_name" {
  type    = string
  default = "payment-api-vpc"
}

# Add: google_compute_network, google_compute_subnetwork with secondary_ranges.
# Output: network, subnets, secondary_range_pods, secondary_range_services.

output "network_name" {
  value = "stub"
}

output "subnet_self_links" {
  value = []
}
