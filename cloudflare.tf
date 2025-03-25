locals {
  cloudflare_zone_id = data.cloudflare_zones.self.result[0].id
}

data "cloudflare_zones" "self" {
  name = var.cloudflare_zone
}

### Cloudflare Resources

# Due to existing bug that causes replacement we will use tunnel_id from variable.
# Resource was created by IaC, than removed from state. 
# Once bug is fixed, will be resumed to state by an import

# https://github.com/cloudflare/terraform-provider-cloudflare/issues/5363
# resource "cloudflare_zero_trust_tunnel_cloudflared" "self" {
#   account_id = var.cloudflare_account_id
#   name       = "mzm-gke-cluster"
#   config_src = "cloudflare" # forces replacement 
# }

resource "cloudflare_dns_record" "mzm-gke-cluster" {
  zone_id = local.cloudflare_zone_id
  name    = var.cloudflare_zone
  content = "${var.cloudflare_zero_trust_tunnel_cloudflared_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = "1"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "self" {
  account_id = var.cloudflare_account_id
  tunnel_id  = var.cloudflare_zero_trust_tunnel_cloudflared_id
  source     = "cloudflare"

  config = {
    ingress = [{
      hostname = "${cloudflare_dns_record.mzm-gke-cluster.name}"
      service  = "http://ingress-nginx-controller.nginx-ingress.svc.cluster.local:80"
      }, {
      service = "http_status:404"
    }]
  }
}

### Kubernetes Resources
resource "kubernetes_namespace" "cloudflared" {
  metadata {
    name = "cloudflared"
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "self" {
  account_id = var.cloudflare_account_id
  tunnel_id  = var.cloudflare_zero_trust_tunnel_cloudflared_id
}

# Create a Kubernetes Secret to store the tunnel token
resource "kubernetes_secret" "cloudflared_tunnel_token" {
  metadata {
    name      = "cloudflared-tunnel-token"
    namespace = kubernetes_namespace.cloudflared.metadata[0].name
  }

  data = {
    "tunnel-token" = data.cloudflare_zero_trust_tunnel_cloudflared_token.self.token
  }

  type = "Opaque"
}

# Updated Kubernetes Deployment to use the Secret
resource "kubernetes_deployment" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.cloudflared.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }

      spec {
        container {
          image = "cloudflare/cloudflared:2025.2.1"
          name  = "cloudflared"
          args = [
            "--metrics",
            "0.0.0.0:2000",
            "--no-autoupdate",
            "tunnel",
            "run",
            "--token",
            "$(TUNNEL_TOKEN)"
          ]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.cloudflared_tunnel_token.metadata[0].name
                key  = "tunnel-token"
              }
            }
          }

          port {
            container_port = 2000
            name           = "metrics"
          }

          liveness_probe {
            http_get {
              path = "/healthcheck"
              port = 2000
            }
            period_seconds    = 10
            failure_threshold = 3
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            period_seconds    = 10
            failure_threshold = 3
          }
        }
      }
    }
  }
}