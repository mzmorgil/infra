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

resource "google_service_account" "cicd_sa" {
  account_id   = "mzm-cicd-sa"
  display_name = "CI/CD Service Account"
  description  = "Service account for GitHub Actions CI/CD"
}

resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions authentication"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  description                        = "OIDC provider for GitHub Actions"
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }
  attribute_condition = "assertion.repository_owner == '${var.github_org}'"
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.cicd_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repo}"
}

resource "google_project_iam_member" "cicd_sa_viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}