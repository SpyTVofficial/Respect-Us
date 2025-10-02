variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API token"
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "k3s-cluster"
}

variable "worker_count" {
  description = "Number of worker nodes to create"
  type        = number
  default     = 2
}

variable "docker_user" {
  description = "Docker registry username"
  type        = string
  sensitive   = true
}

variable "docker_pass" {
  description = "Docker registry password"
  type        = string
  sensitive   = true
}