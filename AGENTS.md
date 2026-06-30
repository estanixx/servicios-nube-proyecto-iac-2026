# AGENTS.md — LLM Orientation

## Project overview

This is a university assignment for *Servicios en la Nube 2026-01*. It provisions a GCP infrastructure with two private nginx instances (production + failover) behind a single global external Application Load Balancer (`EXTERNAL_MANAGED`). Traffic distribution between the two backends is controlled via Terraform variables (`production_weight` and `failover_weight`) using the URL map's `weighted_backend_services` route action. Everything is deployed with a single `terraform apply`.

## File map

| File | Purpose | Resources created |
|------|---------|-------------------|
| `providers.tf` | Declares `hashicorp/google` provider (~>5.0), sets project and region | N/A (provider config) |
| `variables.tf` | Defines all 6 variables with defaults and validations | N/A (variable declarations) |
| `terraform.tfvars.example` | Example values showing all 3 traffic scenarios | N/A (user copies to `terraform.tfvars`) |
| `outputs.tf` | Exposes Load Balancer IP and URL | N/A (output declarations) |
| `network.tf` | Network foundation | VPC, 2 subnets, Cloud Router, Cloud NAT, firewall rule |
| `instances.tf` | Compute layer | Service account, 2 instance templates, 2 zonal MIGs |
| `loadbalancer.tf` | Load balancing layer | Health check, 2 backend services (EXTERNAL_MANAGED), URL map with weighted_backend_services, HTTP proxy, global IP, forwarding rule |
| `scripts/prod-startup.sh` | Startup script for production | nginx install + emerald (#50C878) HTML page |
| `scripts/failover-startup.sh` | Startup script for failover | nginx install + tomato (#FF6347) HTML page |

## Resource dependency order

```
VPC → Subnets → Cloud Router → Cloud NAT → Firewall
                                                ↓
                              Service Account ← Instance Templates
                                     ↓
                                  Zonal MIGs
                                     ↓
                  Health Check → Backend Services → URL Map
                                                       ↓
                                         Target HTTP Proxy
                                                ↓
                                     Global Address (static IP)
                                                ↓
                                    Global Forwarding Rule
```

## Critical gotchas

| Gotcha | Detail |
|--------|--------|
| `weighted_backend_services` for weighted traffic | The URL Map uses `default_route_action.weighted_backend_services` to split requests between `prod-backend` and `failover-backend` by `weight = var.production_weight` / `var.failover_weight`. Weights are relative; a weight of 0 sends no traffic. This requires the modern `EXTERNAL_MANAGED` (Global external Application LB) scheme on the backend services and forwarding rule — the classic `EXTERNAL` scheme does **not** support per-request weighted splitting. `default_service` and `weighted_backend_services` are mutually exclusive in a URL map. |
| LB config propagation delay | The Global external Application LB is an Anycast service. After `apply` or a weight change, allow **~4–5 minutes** for the config to propagate across Google's edge before testing — early requests may time out (curl `000`) or reflect the previous weighting. |
| Health check ranges in firewall | The firewall must allow ingress from `35.191.0.0/16` and `130.211.0.0/22` on TCP port 80. GCP health probes originate from these ranges. |
| Cloud NAT required | Instances are private (no `access_config` block). They need Cloud NAT for `apt-get` to install nginx from the internet. |
| Weights must sum to 100 | `production_weight + failover_weight == 100` is enforced by a `validation` block in `variables.tf`. Any other sum is rejected at plan time. |
| No `access_config` = private instance | Omitting the `access_config` block in `network_interface` ensures the instance has **no public IP**. This is deliberate — all traffic must go through the Load Balancer. |
| `create_before_destroy` on templates | Instance templates are immutable in GCP. The `lifecycle { create_before_destroy = true }` block ensures updates create a new template before destroying the old one. |
| Global vs regional LB resources | This uses a **global** external Application Load Balancer (`EXTERNAL_MANAGED`). All related resources must be global: `google_compute_global_forwarding_rule`, `google_compute_global_address`, `google_compute_target_http_proxy`, and both `google_compute_backend_service` blocks set `load_balancing_scheme = "EXTERNAL_MANAGED"`. The proxy-only subnet is auto-managed. |

## Testing scenarios

1. **Production Active** (`production_weight=100 / failover_weight=0`): `curl` the LB IP → expect emerald page with "Bienvenido al Servicio Principal — Versión Producción"
2. **Full Maintenance** (`production_weight=0 / failover_weight=100`): `curl` the LB IP → expect tomato page with "Error 503 — Sitio en Mantenimiento Programado"
3. **Balanced** (`production_weight=50 / failover_weight=50`): `curl` repeatedly → responses alternate between both pages

## Variable reference

| Variable | Type | Default | Validation |
|----------|------|---------|------------|
| `project_id` | `string` | (required) | none |
| `region` | `string` | `"us-central1"` | none |
| `zone` | `string` | `"us-central1-c"` | none |
| `production_weight` | `number` | `100` | 0–100 |
| `failover_weight` | `number` | `0` | 0–100, and `production_weight + failover_weight == 100` |
| `machine_type` | `string` | `"e2-micro"` | none |
