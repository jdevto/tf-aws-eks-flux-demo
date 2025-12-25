# Flux module - Install Flux v2 via Helm and bootstrap workloads
# This module installs Flux and optionally bootstraps GitRepository and Kustomizations

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

# Generate TLS private key for Weave GitOps
resource "tls_private_key" "weave_gitops_tls" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate TLS self-signed certificate for Weave GitOps
resource "tls_self_signed_cert" "weave_gitops_tls" {
  private_key_pem = tls_private_key.weave_gitops_tls.private_key_pem

  subject {
    common_name  = "weave-gitops.flux-system.svc"
    organization = "Weave GitOps"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [
    "weave-gitops",
    "weave-gitops.flux-system",
    "weave-gitops.flux-system.svc",
    "weave-gitops.flux-system.svc.cluster.local",
    "localhost",
  ]
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

# TLS certificate secret for Weave GitOps
resource "kubernetes_secret" "weave_gitops_tls" {
  metadata {
    name      = "weave-gitops-tls"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "weave-gitops"
      "app.kubernetes.io/component" = "tls"
    }
  }

  data = {
    "tls.crt" = tls_self_signed_cert.weave_gitops_tls.cert_pem
    "tls.key" = tls_private_key.weave_gitops_tls.private_key_pem
  }

  type = "kubernetes.io/tls"

  depends_on = [
    kubernetes_namespace.flux_system,
    tls_self_signed_cert.weave_gitops_tls
  ]
}

# ============================================================================
# Workloads Bootstrap (GitRepository and Kustomizations)
# ============================================================================

# Extract repo name from URL if git_repository_name not provided
locals {
  git_repo_name = var.git_repository_name != null ? var.git_repository_name : (
    var.repo_url != null ? replace(replace(basename(var.repo_url), ".git", ""), "/", "-") : null
  )
}

# Bootstrap GitRepository CR (only if repo_url is provided)
resource "kubectl_manifest" "git_repository" {
  count = var.repo_url != null ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "source.toolkit.fluxcd.io/v1"
    kind       = "GitRepository"
    metadata = {
      name      = local.git_repo_name
      namespace = kubernetes_namespace.flux_system.metadata[0].name
    }
    spec = {
      url      = var.repo_url
      interval = var.sync_interval
      ref = {
        branch = var.repo_branch
      }
      secretRef = var.git_secret_name != null ? {
        name = var.git_secret_name
      } : null
    }
  })

  depends_on = [
    helm_release.flux,
    kubernetes_namespace.flux_system
  ]
}

# Bootstrap Kustomizations for each workload (only if workloads are provided)
resource "kubectl_manifest" "kustomization" {
  for_each = var.repo_url != null && length(var.workloads) > 0 ? { for w in var.workloads : w.name => w } : {}

  yaml_body = yamlencode({
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind       = "Kustomization"
    metadata = {
      name      = each.value.name
      namespace = kubernetes_namespace.flux_system.metadata[0].name
    }
    spec = {
      interval = each.value.sync_interval != null ? each.value.sync_interval : var.sync_interval
      path     = each.value.path
      prune    = each.value.prune != null ? each.value.prune : true
      sourceRef = {
        kind = "GitRepository"
        name = local.git_repo_name
      }
      validation = each.value.validation != null ? each.value.validation : "client"
    }
  })

  depends_on = [
    kubectl_manifest.git_repository
  ]
}
