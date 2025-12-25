output "flux_namespace" {
  description = "Namespace where Flux is installed"
  value       = kubernetes_namespace.flux_system.metadata[0].name
}

output "flux_release_name" {
  description = "Name of the Flux Helm release"
  value       = helm_release.flux.name
}

output "cluster_user_auth_secret_name" {
  description = "Name of the cluster-user-auth secret for Weave GitOps"
  value       = kubernetes_secret.cluster_user_auth.metadata[0].name
}

output "weave_gitops_username" {
  description = "Username for Weave GitOps authentication"
  value       = var.weave_gitops_username
}

output "weave_gitops_password" {
  description = "Generated password for Weave GitOps authentication"
  value       = random_password.weave_gitops_password.result
  sensitive   = true
}
