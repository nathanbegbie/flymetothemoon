variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "server_name" {
  description = "Name of the server"
  type        = string
  default     = "flymetothemoon-server"
}

variable "server_type" {
  description = "Type of server to create (e.g., cax11, cpx21, cx32)"
  type        = string
  default     = "cax11"
}

variable "location" {
  description = "Location of the server (nbg1, fsn1, hel1, ash, hil)"
  type        = string
  default     = "nbg1"
}

variable "image" {
  description = "OS image to use"
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_keys" {
  description = "List of SSH key names to add to the server"
  type        = list(string)
  default     = []
}

variable "enable_backups" {
  description = "Enable automatic backups"
  type        = bool
  default     = false
}

variable "enable_ipv6" {
  description = "Enable IPv6"
  type        = bool
  default     = true
}
