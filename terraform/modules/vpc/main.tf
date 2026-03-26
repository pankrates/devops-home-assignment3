# ---------- VPC ----------
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
}

# ---------- Subnets (dev + staging) ----------
resource "google_compute_subnetwork" "dev" {
  name                     = "${var.network_name}-dev"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.0.0.0/20"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods-dev"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services-dev"
    ip_cidr_range = "10.8.0.0/20"
  }
}

resource "google_compute_subnetwork" "staging" {
  name                     = "${var.network_name}-staging"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.16.0.0/20"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods-staging"
    ip_cidr_range = "10.20.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services-staging"
    ip_cidr_range = "10.24.0.0/20"
  }
}

# ---------- Cloud Router + NAT (private nodes need outbound internet) ----------
resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
