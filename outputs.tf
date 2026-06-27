output "lb_ip_address" {
  description = "Public IP address of the HTTP Load Balancer"
  value       = google_compute_global_address.lb_public_ip.address
}

output "lb_url" {
  description = "URL to access the Load Balancer"
  value       = format("http://%s", google_compute_global_address.lb_public_ip.address)
}
