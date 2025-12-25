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

output "weave_gitops_username" {
  description = "Username for Weave GitOps authentication"
  value       = module.flux.weave_gitops_username
}

output "weave_gitops_password" {
  description = "Generated password for Weave GitOps authentication"
  value       = module.flux.weave_gitops_password
  sensitive   = true
}

# Get Weave GitOps ALB URL from Ingress
data "kubernetes_ingress_v1" "weave_gitops" {
  metadata {
    name      = "weave-gitops"
    namespace = "flux-system"
  }
  depends_on = [module.flux]
}

# Get shared ALB URL from welcome Ingress (represents the shared ALB for all demo apps)
data "kubernetes_ingress_v1" "shared_alb" {
  metadata {
    name      = "welcome"
    namespace = "default"
  }
  depends_on = [module.flux]
}

output "weave_gitops_alb_url" {
  description = "ALB URL for Weave GitOps dashboard"
  value       = try(data.kubernetes_ingress_v1.weave_gitops.status[0].load_balancer[0].ingress[0].hostname, "Not available yet - Ingress may still be provisioning")
}

output "shared_alb_url" {
  description = "Shared ALB URL for demo applications (welcome, podinfo, simple-app)"
  value       = try(data.kubernetes_ingress_v1.shared_alb.status[0].load_balancer[0].ingress[0].hostname, "Not available yet - Ingress may still be provisioning")
}
