output "workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github_provider.name
  description = "Workload Identity Provider resource name for GitHub Actions"
}

output "service_account_email" {
  value       = google_service_account.cicd_sa.email
  description = "Service Account email for GitHub Actions"
}