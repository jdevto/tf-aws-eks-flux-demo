variable "repo_url" {
  description = "Git repository URL containing the workload manifests"
  type        = string
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

variable "flux_namespace" {
  description = "Namespace where Flux is installed"
  type        = string
  default     = "flux-system"
}

variable "flux_ready" {
  description = "Dependency to ensure Flux is ready before creating workloads"
  type        = any
}

variable "workloads" {
  description = "List of workloads to create Kustomizations for"
  type = list(object({
    name          = string
    path          = string
    sync_interval = optional(string)
    prune         = optional(bool)
    validation    = optional(string)
  }))
}
