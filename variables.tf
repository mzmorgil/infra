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

# Cloudflare variables
variable "cloudflare_account_id" {
  description = "Account ID for your Cloudflare account"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone" {
  description = "Domain used to expose the GCP VM instance to the Internet"
  type        = string
}

variable "cloudflare_email" {
  description = "Email address for your Cloudflare account"
  type        = string
  sensitive   = true
}

variable "cloudflare_token" {
  description = "Cloudflare API token created at https://dash.cloudflare.com"
  type        = string
  sensitive   = true
}