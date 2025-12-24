variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "test"
}

variable "cluster_version" {
  type    = string
  default = "1.34"
}

variable "repo_url" {
  description = "Git repository URL that Flux will watch for application manifests"
  type        = string
  default     = "https://github.com/jdevto/tf-aws-eks-flux-demo.git"
}

variable "repo_branch" {
  description = "Git repository branch to sync from"
  type        = string
  default     = "main"
}

variable "flux_sync_interval" {
  description = "Interval at which Flux syncs from Git"
  type        = string
  default     = "5m"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
