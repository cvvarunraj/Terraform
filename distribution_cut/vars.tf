variable "project" {
  description = "The project ID."
  type        = string
}

variable "service" {
  description = "The service ID of the service to monitor with this SLO."
  type        = string
}

variable "sli_range_min" {
  default = 0
  type    = number
}

# There seems to be a bug in the current google provider. We should be able to set this to "-infinity" instead of setting a huge max range.
variable "sli_range_max" {
  default = 9999999999999999999999
  type    = number
}

variable "slo_name" {
  description = "The display name for this SLO"
  type        = string
}

variable "slo_target" {
  description = "The fraction of service that must be good in order for this objective to be met."
  type        = number
}

variable "slo_compliance_period" {
  description = "A time period in days for the error budget, semantically 'in the past X days'."
  type        = number
  default     = 28

  validation {
    condition     = var.slo_compliance_period >= 1 && var.slo_compliance_period <= 30
    error_message = "The slo_compliance_period value must be between 1 to 30 days inclusive."
  }
}

# More details: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_slo#distribution_cut
variable "distribution_filter" {
  description = "A Time Series monitoring filter aggregating values to quantify good events for the service."
  type        = string
  default     = null
}

variable "alert_notification_channels" {
  description = "The notification channels to alert on."
  type        = list(string)
}

variable "enable_alerts" {
  description = "Should the alerts be enabled for this SLO?"
  type        = bool
  default     = true
}

##### Setting this variable to true will create only additional alerts and enable / disable them based on value of enable_alerts var
variable "disable_default_alerts" {
  description = "Should only additional alerts be created for this SLO?"
  type        = bool
  default     = false
}

variable "additional_alerts" {
  description = "Alerts to configure in addition to the defaults."
  type = map(object({
    desc         = string
    burn_rate    = number
    long_window  = number
    short_window = number
    severity     = string
  }))
  default = null
}

variable "deadman_alert" {
  description = "An optional deadman alert for this SLO. Set 'enabled' to true to activate.  If enabled, 'filter' must be set."
  type = object({
    enabled            = optional(bool)
    duration_threshold = optional(string)
    filter             = optional(string) # Only optional if enabled = false
  })

  default = {}
}

variable "pd_service_name" {
  description = "The PagerDuty service name that this alert should be routed to. This string is used to match the service name so it needs to be identical to the service name."
  type        = string
}
