variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  type        = string
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.4"
}

variable "git_repo_url" {
  description = "Git repository URL containing application manifests"
  type        = string
}

variable "git_revision" {
  description = "Git revision to use (branch, tag, commit)"
  type        = string
  default     = "main"
}

variable "git_ssh_key" {
  description = "SSH private key for Git repository access"
  type        = string
  default     = ""
  sensitive   = true
}

variable "apps_path" {
  description = "Path in Git repository containing application manifests"
  type        = string
  default     = "apps"
}

variable "node_selector" {
  description = "Node selector for ArgoCD components"
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  type        = string
  description = "AWS region where the secret will be created"
}