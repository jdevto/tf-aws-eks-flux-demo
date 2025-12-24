# Flux Workloads Module - Bootstrap GitRepository and Kustomizations
# This module bootstraps Flux GitOps resources for workloads
# The actual workload manifests should be in the Git repository

# Extract repo name from URL if git_repository_name not provided
locals {
  git_repo_name = var.git_repository_name != null ? var.git_repository_name : replace(replace(basename(var.repo_url), ".git", ""), "/", "-")
}

# Bootstrap GitRepository CR
resource "kubectl_manifest" "git_repository" {
  yaml_body = yamlencode({
    apiVersion = "source.toolkit.fluxcd.io/v1"
    kind       = "GitRepository"
    metadata = {
      name      = local.git_repo_name
      namespace = var.flux_namespace
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

  depends_on = [var.flux_ready]
}

# Bootstrap Kustomizations for each workload
resource "kubectl_manifest" "kustomization" {
  for_each = { for w in var.workloads : w.name => w }

  yaml_body = yamlencode({
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind       = "Kustomization"
    metadata = {
      name      = each.value.name
      namespace = var.flux_namespace
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
