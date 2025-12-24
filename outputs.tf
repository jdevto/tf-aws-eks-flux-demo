# Outputs are commented out as they reference modules that may not be fully implemented
# Uncomment and update as needed when modules are complete

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_data" {
  description = "Cluster CA certificate data"
  value       = module.eks.cluster_ca_data
  sensitive   = true
}

output "git_repository_name" {
  description = "Name of the Flux GitRepository resource"
  value       = module.flux_workloads.git_repository_name
}
