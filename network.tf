# =============================================================================
# Network Layer — VPC, subnets, Cloud NAT, and firewall rules
# =============================================================================

resource "google_compute_network" "app_vpc" {
  name                    = "app-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "private_prod" {
  name          = "private-prod"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.app_vpc.id

  private_ip_google_access = true
}

resource "google_compute_subnetwork" "private_failover" {
  name          = "private-failover"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.app_vpc.id

  private_ip_google_access = true
}

resource "google_compute_router" "app_router" {
  name    = "app-router"
  network = google_compute_network.app_vpc.id
  region  = var.region

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "app_nat" {
  name                               = "app-nat"
  router                             = google_compute_router.app_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "allow_health_check" {
  name      = "allow-health-check"
  network   = google_compute_network.app_vpc.id
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["http-server"]
}
