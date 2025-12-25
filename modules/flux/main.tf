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

# Generate random password for Weave GitOps
resource "random_password" "weave_gitops_password" {
  length  = 16
  special = true
  # Exclude characters that might cause issues in URLs or shells
  override_special = "!@#$%^&*"
}

# Generate bcrypt hash of the password
data "utilities_bcrypt_hash" "weave_gitops" {
  plaintext = random_password.weave_gitops_password.result
  cost      = 10
}

# Cluster user authentication secret for Weave GitOps
resource "kubernetes_secret" "cluster_user_auth" {
  metadata {
    name      = "cluster-user-auth"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "weave-gitops"
      "app.kubernetes.io/component" = "auth"
    }
  }

  data = {
    username = var.weave_gitops_username
    password = data.utilities_bcrypt_hash.weave_gitops.hash
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.flux_system,
    data.utilities_bcrypt_hash.weave_gitops
  ]
}
