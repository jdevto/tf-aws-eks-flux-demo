variable "flux_version" {
  description = "Version of Flux Helm chart to install"
  type        = string
  default     = "2.17.2"
}

variable "helm_values" {
  description = "Custom Helm values for Flux installation. If null, uses default component configuration."
  type        = string
  default     = null
}

variable "weave_gitops_username" {
  description = "Username for Weave GitOps cluster user authentication"
  type        = string
  default     = "admin"
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint URL. Used as explicit dependency to ensure cluster is ready before creating resources."
  type        = string
}

# Workloads configuration
variable "repo_url" {
  description = "Git repository URL containing the workload manifests"
  type        = string
  default     = null
}

variable "repo_branch" {
  description = "Git repository branch to sync from"
  type        = string
  default     = "main"
}

variable "git_repository_name" {
  description = "Name for the Flux GitRepository Kubernetes resource. If null, derived from repo_url."
  type        = string
  default     = null
}

variable "sync_interval" {
  description = "Default sync interval for workloads"
  type        = string
  default     = "5m"
}

variable "git_secret_name" {
  description = "Name of Kubernetes secret containing Git credentials (for private repos). Leave null for public repos."
  type        = string
  default     = null
}

variable "workloads" {
  description = "List of workloads to create Kustomizations for. If empty, no workloads are bootstrapped."
  type = list(object({
    name          = string
    path          = string
    sync_interval = optional(string)
    prune         = optional(bool)
    validation    = optional(string)
  }))
  default = []
}
