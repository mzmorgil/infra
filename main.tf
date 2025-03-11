# Enable required APIs
resource "google_project_service" "cloudresourcemanager" {
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
}

resource "google_project_service" "container" {
  service = "container.googleapis.com"
}

resource "google_project_service" "storage" {
  service = "storage.googleapis.com"
}

resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
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

# Grant CI/CD service account necessary roles for Terraform
resource "google_project_iam_member" "cicd_sa_roles" {
  for_each = toset([
    "roles/storage.admin",         # For Terraform state bucket
    "roles/compute.admin",         # For VPC and networking
    "roles/container.admin",       # For GKE cluster management
    "roles/storage.objectAdmin",
    "roles/viewer"
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

# Static Public IP for the entry node
resource "google_compute_address" "static_ip" {
  name    = "mzm-static-ip"
  region  = var.region
  project = var.project_id
}

# GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name       = var.cluster_name
  location   = var.region
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

  depends_on = [
    google_project_service.container,
    google_project_service.compute,
  ]
}

# Node Pool with Static IP (Entry Point)
resource "google_container_node_pool" "entry_node_pool" {
  name           = "entry-node-pool"
  cluster        = google_container_cluster.gke_cluster.name
  location       = var.region
  node_locations = ["me-west1-a"]
  node_count     = 1

  node_config {
    machine_type = "e2-small"
    disk_size_gb = 20
    spot         = true
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    tags = ["entry-node"]
  }
}

# Additional Spot Node Pool
resource "google_container_node_pool" "spot_node_pool" {
  name           = "spot-node-pool"
  cluster        = google_container_cluster.gke_cluster.name
  location       = var.region
  node_locations = ["me-west1-a"]
  node_count     = 1

  node_config {
    machine_type = "e2-micro"
    disk_size_gb = 20
    spot         = true
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

# Firewall Rule for entry node
resource "google_compute_firewall" "allow_entry" {
  name    = "allow-entry-node"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["entry-node"]
}