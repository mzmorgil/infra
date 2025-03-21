# Enable required APIs using for_each
resource "google_project_service" "apis" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
  ])
  service            = each.key
  project            = var.project_id
  disable_on_destroy = false
}

# GCS Bucket for Terraform State
resource "google_storage_bucket" "terraform_state" {
  name                        = "mzm-org-il-terraform-state"
  location                    = "ME-WEST1"
  force_destroy               = false
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 5
    }
  }
}

# Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions"
  project                   = var.project_id
}

# Workload Identity Provider for GitHub Actions
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  description                        = "OIDC provider for GitHub Actions"
  attribute_condition                = "assertion.repository_owner == 'mzmorgil'"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Service Account for CI/CD (Terraform/GitHub Actions)
resource "google_service_account" "cicd_sa" {
  account_id   = "mzm-cicd-sa"
  display_name = "CI/CD Service Account"
  project      = var.project_id
}

# Grant CI/CD service account full admin access
resource "google_project_iam_member" "cicd_sa_roles" {
  for_each = toset([
    "roles/owner"
  ])
  role    = each.key
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
  project = var.project_id
}

# Allow GitHub Actions to impersonate the CI/CD service account
resource "google_service_account_iam_member" "github_impersonation" {
  service_account_id = google_service_account.cicd_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/mzmorgil/infra"
}

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

  depends_on = [
    google_project_service.apis,
  ]
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

# Firewall Rule to allow traffic to all nodes
resource "google_compute_firewall" "allow_web_traffic" {
  name    = "allow-web-traffic"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}