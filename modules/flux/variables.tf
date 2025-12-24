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
