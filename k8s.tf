### nginx-ingress

resource "kubernetes_namespace" "nginx_ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

resource "helm_release" "nginx_ingress" {
  name = "ingress-nginx"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  namespace = kubernetes_namespace.nginx_ingress.metadata[0].name

  set {
    name  = "controller.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "controller.replicaCount"
    value = "1"
  }
}