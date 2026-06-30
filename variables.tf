variable "project_id" {
  description = "GCP project ID where resources will be created"
  type        = string
  default     = "servicios-nube-iac-2026"
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "production_weight" {
  description = "Traffic weight for the production backend (0-100, must sum to 100 with failover_weight)"
  type        = number
  default     = 100

  validation {
    condition     = var.production_weight >= 0 && var.production_weight <= 100
    error_message = "production_weight must be between 0 and 100."
  }
}

variable "failover_weight" {
  description = "Traffic weight for the failover backend (0-100, must sum to 100 with production_weight)"
  type        = number
  default     = 0

  validation {
    condition     = var.failover_weight >= 0 && var.failover_weight <= 100
    error_message = "failover_weight must be between 0 and 100."
  }

  validation {
    condition     = var.production_weight + var.failover_weight == 100
    error_message = "production_weight (${var.production_weight}) + failover_weight (${var.failover_weight}) must equal 100."
  }
}

variable "machine_type" {
  description = "GCE machine type for instances"
  type        = string
  default     = "e2-micro"
}

variable "zone" {
  description = "GCP zone for instances"
  type        = string
  default     = "us-central1-c"
}
