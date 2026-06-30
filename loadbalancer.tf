# =============================================================================
# Load Balancer Layer — Global external Application Load Balancer
# (EXTERNAL_MANAGED) with weighted_backend_services
# =============================================================================
#
# Deterministic weight-based traffic splitting is achieved with the modern
# Global external Application Load Balancer (load_balancing_scheme =
# "EXTERNAL_MANAGED") and the URL map's weighted_backend_services route action.
# Each MIG lives in its own backend service, and the URL map splits requests
# between them according to production_weight / failover_weight. Unlike
# capacity_scaler on the classic LB, this splits traffic per-request even at
# low request volume, so consecutive requests alternate as required.
#
#   Scenario          | production_weight | failover_weight
#   ------------------|-------------------|----------------
#   Production Active | 100               | 0
#   Maintenance       | 0                 | 100
#   Balanced          | 50                | 50
#
# Weights are relative; a weight of 0 sends no traffic to that backend service.

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

resource "google_compute_backend_service" "prod_backend" {
  name                  = "prod-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 10
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_instance_group_manager.prod_mig.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.app_health_check.id]
}

resource "google_compute_backend_service" "failover_backend" {
  name                  = "failover-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 10
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_instance_group_manager.failover_mig.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.app_health_check.id]
}

resource "google_compute_url_map" "app_url_map" {
  name = "app-url-map"

  # All traffic is split by weight via the default route action. A URL map
  # cannot set default_service together with weighted_backend_services.
  default_route_action {
    weighted_backend_services {
      backend_service = google_compute_backend_service.prod_backend.id
      weight          = var.production_weight
    }

    weighted_backend_services {
      backend_service = google_compute_backend_service.failover_backend.id
      weight          = var.failover_weight
    }
  }
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
