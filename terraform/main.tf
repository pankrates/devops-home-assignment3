terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# =====================================================================
# Enable required GCP APIs
# =====================================================================

locals {
  apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "connectgateway.googleapis.com",
    "gkehub.googleapis.com",
    "iam.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)
  project  = var.project_id
  service  = each.value

  disable_on_destroy = false
}

# =====================================================================
# Modules
# =====================================================================

module "vpc" {
  source       = "./modules/vpc"
  project_id   = var.project_id
  region       = var.region
  network_name = var.network_name

  depends_on = [google_project_service.apis]
}

module "gke" {
  source                   = "./modules/gke"
  project_id               = var.project_id
  region                   = var.region
  cluster_name             = var.cluster_name
  network                  = module.vpc.network_name
  subnetwork               = module.vpc.dev_subnet_name
  secondary_range_pods     = module.vpc.dev_pods_range_name
  secondary_range_services = module.vpc.dev_services_range_name
  node_locations           = var.node_locations

  depends_on = [google_project_service.apis]
}

module "secrets" {
  source     = "./modules/secrets"
  project_id = var.project_id

  depends_on = [google_project_service.apis]
}

module "iam" {
  source               = "./modules/iam"
  project_id           = var.project_id
  cluster_name         = module.gke.cluster_name
  cluster_location     = module.gke.region
  kubernetes_namespace = "payment-api"
  kubernetes_sa_name   = "payment-api"
  secret_id            = module.secrets.secret_id

  # Workload Identity pool is created as a side effect of GKE cluster creation.
  # Explicit depends_on ensures the pool exists before IAM binding.
  depends_on = [module.gke]
}

# =====================================================================
# Artifact Registry — Docker repository for CI/CD
# =====================================================================

resource "google_artifact_registry_repository" "payment_api" {
  project       = var.project_id
  location      = var.region
  repository_id = "payment-api-repo"
  format        = "DOCKER"
  description   = "Docker repository for payment-api images"
}

# =====================================================================
# Static IP for Ingress
# =====================================================================

resource "google_compute_global_address" "ingress_ip" {
  project = var.project_id
  name    = "payment-api-ingress-ip"
}

# =====================================================================
# Observability — Uptime check + Alert policy
# =====================================================================

resource "google_monitoring_uptime_check_config" "health" {
  project      = var.project_id
  display_name = "payment-api-health"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/health"
    port           = 80
    use_ssl        = false
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = google_compute_global_address.ingress_ip.address
    }
  }
}

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "DevOps Email"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "uptime" {
  project      = var.project_id
  display_name = "Payment API Health Check Failure"
  combiner     = "OR"

  conditions {
    display_name = "Uptime check failing"

    condition_threshold {
      filter          = "resource.type = \"uptime_url\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id = \"${google_monitoring_uptime_check_config.health.uptime_check_id}\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_NEXT_OLDER"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# =====================================================================
# Outputs (used by CI/CD pipeline and Helm)
# =====================================================================

output "cluster_name" {
  value = module.gke.cluster_name
}

output "region" {
  value = module.gke.region
}

output "gsa_email" {
  value = module.iam.gsa_email
}

output "secret_id" {
  value = module.secrets.secret_id
}

output "ingress_ip_name" {
  value = google_compute_global_address.ingress_ip.name
}

output "ingress_ip_address" {
  value = google_compute_global_address.ingress_ip.address
}
