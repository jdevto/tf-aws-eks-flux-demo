# Flux module - Install Flux v2 via Helm
# This module only installs Flux. Workloads should be managed separately via GitOps.

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
    labels = {
      "app.kubernetes.io/name"      = "flux"
      "app.kubernetes.io/instance"  = "flux"
      "app.kubernetes.io/component" = "system"
    }
  }
}

# Install Flux via Helm
resource "helm_release" "flux" {
  name       = "flux2"
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2"
  namespace  = kubernetes_namespace.flux_system.metadata[0].name
  version    = var.flux_version

  values = var.helm_values != null ? [var.helm_values] : [
    yamlencode({
      components = {
        source-controller = {
          enabled = true
        }
        kustomize-controller = {
          enabled = true
        }
        helm-controller = {
          enabled = true
        }
        notification-controller = {
          enabled = true
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.flux_system
  ]
}
