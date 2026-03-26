# ---------- GKE Cluster ----------
resource "google_container_cluster" "primary" {
  timeouts {
    create = "60m"
    delete = "30m"
  }

  name     = var.cluster_name
  project  = var.project_id
  location = var.region

  network    = var.network
  subnetwork = var.subnetwork

  # Restrict node zones to avoid zones with capacity issues (e.g. GCE_STOCKOUT in zone b)
  node_locations = length(var.node_locations) > 0 ? var.node_locations : null

  # Remove default node pool — we manage our own below
  remove_default_node_pool = true
  initial_node_count       = 1

  # Default node pool config (used during cluster creation, then removed)
  node_config {
    disk_size_gb = 20
  }

  # VPC-native using secondary ranges from VPC module
  ip_allocation_policy {
    cluster_secondary_range_name  = var.secondary_range_pods
    services_secondary_range_name = var.secondary_range_services
  }

  # Private cluster — no public IPs on nodes
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true  # fully private — CI/CD access via Connect Gateway
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Release channel REGULAR — Google manages version upgrades
  release_channel {
    channel = "REGULAR"
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Required when enable_private_endpoint = true.
  # Only controls access from within VPC — endpoint is still private.
  # Connect Gateway bypasses this (goes through Google API).
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.0.0/8"
      display_name = "vpc-internal"
    }
  }

  # Deletion protection off for dev/assignment (enable in production)
  deletion_protection = false
}

# ---------- Node Pool ----------
resource "google_container_node_pool" "default" {
  name     = "${var.cluster_name}-pool"
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.primary.name

  initial_node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 20
    preemptible  = false

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    # Workload Identity on nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# ---------- Fleet membership + Connect Gateway ----------
# Registers the cluster in a Fleet so CI/CD can reach the private
# master via Connect Gateway (no VPN or public endpoint needed).

resource "google_gke_hub_membership" "primary" {
  membership_id = var.cluster_name
  project       = var.project_id
  location      = var.region

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.primary.id}"
    }
  }

  # Wait for node pool — GKE handles one operation at a time
  depends_on = [google_container_node_pool.default]
}


# Connect Gateway is automatically enabled when a cluster is registered in a Fleet.
# No explicit google_gke_hub_feature resource needed.
