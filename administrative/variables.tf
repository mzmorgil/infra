variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
  default     = "mzm-org-il"
}

variable "region" {
  description = "GCP Region"
  default     = "me-west1"
}

variable "github_org" {
  description = "The GitHub organization name"
  type        = string
  default     = "mzmorgil"
}

variable "github_repo" {
  description = "The GitHub repository name (e.g., org/repo)"
  type        = string
  default     = "mzmorgil/infra"
}

variable "bucket_name" {
  description = "The GCS bucket name for Terraform state"
  type        = string
  default     = "mzm-org-il-terraform-state"
}

