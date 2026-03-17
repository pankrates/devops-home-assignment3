# Stub: Call modules/vpc, modules/gke, modules/iam. Create Secret Manager secret (reference by name only).
# Use variables from terraform.tfvars. Output cluster_name, region, gsa_email for pipeline/Helm.

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# provider "google" { ... }
# module "vpc" { ... }
# module "gke" { ... }
# module "iam" { ... }
# google_secret_manager_secret (no secret value; add version separately or via app bootstrap)
