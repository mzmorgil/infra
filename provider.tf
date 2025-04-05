terraform {
  # GCS Backend for state storage
  backend "gcs" {
    bucket = "mzm-org-il-terraform-state"
    prefix = "gke-cluster/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
  }
}

provider "google" {
  project = "mzm-org-il"
  region  = "me-west1"
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.gke_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.gke_cluster.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate)
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}