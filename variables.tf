variable "project_id" {
  description = "GCP Project ID"
  default     = "mzm-org-il"
}

variable "region" {
  description = "GCP Region"
  default     = "me-west1"
}

variable "singlezone" {
  description = "GCP Zone for node pools"
  default     = "me-west1-c"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  default     = "mzm-gke-cluster"
}