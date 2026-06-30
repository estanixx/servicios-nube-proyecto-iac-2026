# Proyecto Terraform — GCP Weighted Load Balancer

University cloud services project deploying two independent nginx instances (production + failover) behind a single public HTTP Load Balancer on GCP, with traffic distribution controlled entirely via Terraform variables. Deployment via single `terraform apply` — no manual SSH or console intervention.

## Prerequisites

- GCP project with billing enabled
- `gcloud` CLI configured with credentials
- Terraform >= 1.6
- Environment variable: `GOOGLE_APPLICATION_CREDENTIALS`

## Quick start

```bash
terraform init
terraform apply
```

`project_id` defaults to the project this repository is meant to deploy into
(`servicios-nube-iac-2026`), so `terraform apply` runs without any extra
configuration. Override it if needed with `-var="project_id=YOUR_PROJECT"`.
Authentication uses your active `gcloud` credentials (Application Default
Credentials); the reviewer is granted the `roles/editor` role on the project.

After apply completes, get the Load Balancer IP:

```bash
terraform output lb_url
```

## Architecture overview

The infrastructure is composed of three layers:

1. **Network**: Custom VPC with two private subnets (`10.0.1.0/24` and `10.0.2.0/24`), Cloud Router + Cloud NAT for outbound internet access, and firewall rules allowing health check probes from Google's LB ranges.
2. **Compute**: Two zonal Managed Instance Groups (MIGs), each with `target_size=1`, running `e2-micro` instances with Debian-11 and nginx. Instances have **no public IPs** — all traffic arrives through the Load Balancer.
3. **Load Balancer**: Global external Application Load Balancer (`EXTERNAL_MANAGED`) with a static IPv4 address. Each MIG has its own backend service (`prod-backend`, `failover-backend`), and the URL map's `weighted_backend_services` route action splits traffic between them according to `production_weight` and `failover_weight`. This splits traffic per-request — even at low request volume — so the balanced scenario alternates between both services.

## Traffic scenarios

Traffic distribution is controlled by two variables: `production_weight` and `failover_weight`. They **must sum to 100**.

| Scenario | `production_weight` | `failover_weight` | Expected behavior |
|----------|---------------------|-------------------|-------------------|
| Production Active | 100 | 0 | 100% traffic to production (emerald background) |
| Full Maintenance | 0 | 100 | 100% traffic to failover (tomato background) |
| Balanced | 50 | 50 | ~50/50 split between both instances |

### How to apply each scenario

Edit `terraform.tfvars`, uncomment the desired scenario's weight values, then run:

```bash
terraform apply
```

Test with:

```bash
curl http://$(terraform output -raw lb_ip_address)
```

For the Balanced scenario, run the curl command several times — consecutive requests alternate between the two responses.

> **Note on propagation:** the global Application Load Balancer is an Anycast service. After `terraform apply` (or after changing the weights), allow **~4–5 minutes** for the configuration to propagate across Google's edge before testing — early requests may time out or return the previous weighting until propagation completes.

## Evidencias

Request logs captured live against the deployed Load Balancer for each scenario
are in [`evidence/`](evidence/):

| Scenario | Weights | Log | Result |
|----------|---------|-----|--------|
| Production Active | 100 / 0 | [`escenario-1-produccion.log`](evidence/escenario-1-produccion.log) | 20/20 production |
| Maintenance | 0 / 100 | [`escenario-2-mantenimiento.log`](evidence/escenario-2-mantenimiento.log) | 20/20 maintenance |
| Balanced | 50 / 50 | [`escenario-3-balanceado.log`](evidence/escenario-3-balanceado.log) | alternating, ~50/50 |

## File structure

| File | Description |
|------|-------------|
| `providers.tf` | Google provider config, `required_providers` block |
| `variables.tf` | All variables with types, defaults, and validations |
| `terraform.tfvars.example` | Example tfvars with all 3 scenarios documented |
| `outputs.tf` | `lb_ip_address` and `lb_url` outputs |
| `network.tf` | VPC, 2 private subnets, Cloud Router, Cloud NAT, firewall |
| `instances.tf` | Service account, 2 instance templates, 2 zonal MIGs |
| `loadbalancer.tf` | Health check, two backend services, URL map with weighted routing, HTTP proxy, global IP, forwarding rule |
| `scripts/prod-startup.sh` | Startup script — nginx + emerald production HTML |
| `scripts/failover-startup.sh` | Startup script — nginx + tomato maintenance HTML |
| `AGENTS.md` | LLM-oriented documentation for codebase understanding |

## Cleanup

```bash
terraform destroy
```

Verify in GCP Console that all resources have been removed. Leaving resources active will cause conflicts when the professor deploys from your repository.
