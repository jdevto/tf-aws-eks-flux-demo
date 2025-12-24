output "flux_namespace" {
  description = "Namespace where Flux is installed"
  value       = kubernetes_namespace.flux_system.metadata[0].name
}

output "flux_release_name" {
  description = "Name of the Flux Helm release"
  value       = helm_release.flux.name
}
