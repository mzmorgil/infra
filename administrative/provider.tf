terraform {
  # GCS Backend for state storage
  backend "gcs" {
    bucket = "mzm-org-il-terraform-state"
    prefix = "administrative/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6"
    }

    github = {
      source  = "integrations/github"
      version = "~> 6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "github" {
    owner = "mzmorgil"
}