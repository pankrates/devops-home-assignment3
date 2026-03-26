output "network_name" {
  value = google_compute_network.vpc.name
}

output "network_id" {
  value = google_compute_network.vpc.id
}

output "dev_subnet_name" {
  value = google_compute_subnetwork.dev.name
}

output "staging_subnet_name" {
  value = google_compute_subnetwork.staging.name
}

output "dev_pods_range_name" {
  value = "pods-dev"
}

output "dev_services_range_name" {
  value = "services-dev"
}

output "staging_pods_range_name" {
  value = "pods-staging"
}

output "staging_services_range_name" {
  value = "services-staging"
}
