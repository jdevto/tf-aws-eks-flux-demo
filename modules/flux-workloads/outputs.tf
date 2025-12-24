output "git_repository_name" {
  description = "Name of the Flux GitRepository resource"
  value       = local.git_repo_name
}

output "kustomization_names" {
  description = "Names of the created Kustomization resources"
  value       = { for w in var.workloads : w.name => w.name }
}
