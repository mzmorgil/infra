variable "project_id" {
  description = "GCP Project ID"
  default     = "mzm-org-il"
}

variable "region" {
  description = "GCP Region"
  default     = "me-west1"
}

variable "zonal" {
  description = "GCP Single Zone"
  default     = "me-west1-c"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  default     = "mzm-gke-cluster"
}