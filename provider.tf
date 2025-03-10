terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6"
    }
  }

  # GCS Backend for state storage
  backend "gcs" {
    bucket = "mzm-org-il-terraform-state"
    prefix = "gke-cluster/state"
  }
}

provider "google" {
  project = "mzm-org-il"
  region  = "me-west1"
}