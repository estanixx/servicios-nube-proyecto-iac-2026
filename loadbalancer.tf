# =============================================================================
# Load Balancer Layer — Health Check, Backend Service, URL Map, Proxy, and
# Forwarding Rule
# =============================================================================
#
# Weighted traffic distribution is achieved by placing both MIGs as backends
# in a single backend service and using capacity_scaler to control the
# proportion of traffic each group receives:
#
#   Scenario          | prod capacity_scaler | fail capacity_scaler
#   ------------------|---------------------|---------------------
#   Production Active | 1.0                 | 0.0
#   Maintenance       | 0.0                 | 1.0
#   Balanced          | 0.5                 | 0.5

resource "google_compute_health_check" "app_health_check" {
  name                = "app-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port = 80
  }
}

resource "google_compute_backend_service" "app_backend" {
  name        = "app-backend"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 10

  backend {
    group                 = google_compute_instance_group_manager.prod_mig.instance_group
    balancing_mode        = "RATE"
    capacity_scaler       = var.production_weight / 100.0
    max_rate_per_instance = 50
  }

  backend {
    group                 = google_compute_instance_group_manager.failover_mig.instance_group
    balancing_mode        = "RATE"
    capacity_scaler       = var.failover_weight / 100.0
    max_rate_per_instance = 50
  }

  health_checks = [google_compute_health_check.app_health_check.id]
}

resource "google_compute_url_map" "app_url_map" {
  name            = "app-url-map"
  default_service = google_compute_backend_service.app_backend.id
}

resource "google_compute_target_http_proxy" "app_http_proxy" {
  name    = "app-http-proxy"
  url_map = google_compute_url_map.app_url_map.id
}

resource "google_compute_global_address" "lb_public_ip" {
  name = "lb-public-ip"
}

resource "google_compute_global_forwarding_rule" "app_forwarding_rule" {
  name                  = "app-forwarding-rule"
  target                = google_compute_target_http_proxy.app_http_proxy.id
  port_range            = "80"
  ip_protocol           = "TCP"
  ip_address            = google_compute_global_address.lb_public_ip.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
