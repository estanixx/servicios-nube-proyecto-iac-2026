# =============================================================================
# Compute Layer — Service Account, Instance Templates, and Managed Instance
# Groups
# =============================================================================

resource "google_service_account" "app_sa" {
  account_id   = "app-sa"
  display_name = "App Service Account"
}

resource "google_compute_instance_template" "prod_template" {
  name         = "prod-template"
  machine_type = var.machine_type

  disk {
    source_image = "debian-cloud/debian-11"
    boot         = true
    auto_delete  = true
    disk_size_gb = 10
    disk_type    = "pd-standard"
  }

  network_interface {
    network    = google_compute_network.app_vpc.id
    subnetwork = google_compute_subnetwork.private_prod.id
  }

  service_account {
    email  = google_service_account.app_sa.email
    scopes = ["cloud-platform"]
  }

  tags = ["http-server"]

  metadata_startup_script = file("${path.module}/scripts/prod-startup.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_template" "failover_template" {
  name         = "failover-template"
  machine_type = var.machine_type

  disk {
    source_image = "debian-cloud/debian-11"
    boot         = true
    auto_delete  = true
    disk_size_gb = 10
    disk_type    = "pd-standard"
  }

  network_interface {
    network    = google_compute_network.app_vpc.id
    subnetwork = google_compute_subnetwork.private_failover.id
  }

  service_account {
    email  = google_service_account.app_sa.email
    scopes = ["cloud-platform"]
  }

  tags = ["http-server"]

  metadata_startup_script = file("${path.module}/scripts/failover-startup.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "prod_mig" {
  name               = "prod-mig"
  zone               = var.zone
  target_size        = 1
  base_instance_name = "prod"

  version {
    instance_template = google_compute_instance_template.prod_template.self_link
  }

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_instance_group_manager" "failover_mig" {
  name               = "failover-mig"
  zone               = var.zone
  target_size        = 1
  base_instance_name = "failover"

  version {
    instance_template = google_compute_instance_template.failover_template.self_link
  }

  named_port {
    name = "http"
    port = 80
  }
}
