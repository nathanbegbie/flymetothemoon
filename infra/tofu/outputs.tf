output "server_id" {
  description = "ID of the created server"
  value       = hcloud_server.app_server.id
}

output "server_name" {
  description = "Name of the server"
  value       = hcloud_server.app_server.name
}

output "server_ipv4" {
  description = "IPv4 address of the server"
  value       = hcloud_server.app_server.ipv4_address
}

output "server_ipv6" {
  description = "IPv6 address of the server"
  value       = hcloud_server.app_server.ipv6_address
}

output "server_status" {
  description = "Status of the server"
  value       = hcloud_server.app_server.status
}

output "ssh_command" {
  description = "SSH command to connect to the server (using IPv4)"
  value       = "ssh root@${hcloud_server.app_server.ipv4_address}"
}

output "firewall_id" {
  description = "ID of the firewall"
  value       = hcloud_firewall.web_firewall.id
}
