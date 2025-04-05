module "mzm-gke-cloudflare" {
  count = 1
  source = "./tofu-modules/cloudflare"
  cloudflare_zone = var.cloudflare_zone
  cloudflare_account_id = var.cloudflare_account_id
}
