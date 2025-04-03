# Reference to your existing repository
resource "github_repository" "infra" {
  name = "infra"
  description = "Tech Support"
  allow_auto_merge = true
  allow_merge_commit = false
  allow_rebase_merge = false
  delete_branch_on_merge = true
  squash_merge_commit_title = "PR_TITLE"
  vulnerability_alerts = true
}

resource "github_repository_environment" "mzm_prod" {
  repository  = github_repository.infra.name
  environment = "mzm-prod"

  deployment_branch_policy {
    protected_branches    = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "main" {
  repository     = github_repository.infra.name
  environment    = github_repository_environment.mzm_prod.environment
  branch_pattern = "main"
}