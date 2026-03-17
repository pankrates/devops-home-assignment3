# Stub: Private GKE cluster, VPC-native, release channel, Workload Identity enabled.
# Use secondary ranges from VPC module for pods and services.
# No public endpoint; no public node IPs.

variable "project_id" { type = string }
variable "region" { type = string }
variable "cluster_name" { type = string }
variable "network" { type = string }
variable "subnetwork" { type = string }
variable "secondary_range_pods" { type = string }
variable "secondary_range_services" { type = string }

# Add: google_container_cluster (private_cluster_config, workload_identity_config, ip_allocation_policy).
# Output: cluster_name, cluster_ca_certificate, endpoint (if needed for pipeline), region.

output "cluster_name" {
  value = var.cluster_name
}

output "region" {
  value = var.region
}
