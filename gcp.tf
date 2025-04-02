
# Custom Service Account for GKE Nodes
resource "google_service_account" "gke_node_sa" {
  account_id   = "mzm-gke-node-sa"
  display_name = "GKE Node Service Account"
  project      = var.project_id
}

# Grant GKE Node Service Account the minimal role
resource "google_project_iam_member" "gke_node_sa_role" {
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
  project = var.project_id
}

# Custom VPC
resource "google_compute_network" "vpc" {
  name                    = "mzm-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet for GKE
resource "google_compute_subnetwork" "subnet" {
  name          = "mzm-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

# GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name       = var.cluster_name
  location   = var.zonal
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
  project    = var.project_id

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.1.0.0/16"
    services_ipv4_cidr_block = "10.2.0.0/20"
  }

  initial_node_count       = 1
  remove_default_node_pool = true

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = false
    }
  }

  logging_config {
    enable_components = []
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  addons_config {
    http_load_balancing {
      disabled = true # Explicitly disable HTTP Load Balancing add-on
    }
    horizontal_pod_autoscaling {
      disabled = true
    }
    network_policy_config {
      disabled = true
    }
    dns_cache_config {
      enabled = true
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# Spot Node Pool
resource "google_container_node_pool" "spot_node_pool" {
  name       = "spot-node-pool"
  cluster    = google_container_cluster.gke_cluster.name
  location   = var.zonal
  node_count = 1

  node_config {
    machine_type    = "e2-small"
    disk_size_gb    = 20
    disk_type       = "pd-standard"
    spot            = true
    service_account = google_service_account.gke_node_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}
