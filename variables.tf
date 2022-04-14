variable "api_url" {
  type        = string
  description = "URL of alternative CAST AI API to be used during development or testing"
  default     = "https://api.cast.ai"
}

variable "project_id" {
  type        = string
  description = "The project id from GCP"
}

variable "gke_cluster_name" {
  type        = string
  description = "Name of the cluster to be connected to CAST AI."
}

variable "autoscaler_policies_json" {
  type        = string
  description = "Optional json object to override CAST AI cluster autoscaler policies"
  default     = ""
}

variable "delete_nodes_on_disconnect" {
  type        = bool
  description = "Optionally delete Cast AI created nodes when the cluster is destroyed"
  default     = false
}

variable "ssh_public_key" {
  type        = string
  description = "Optional SSH public key for VM instances. Accepted values are base64 encoded SSH public key or AWS key pair ID"
  default     = null
}

variable "gke_cluster_region" {
  type        = string
  description = "Region of the cluster to be connected to CAST AI."
}

variable "gke_credentials" {
  type        = string
  description = "Optional GCP Service account credentials.json"
}

