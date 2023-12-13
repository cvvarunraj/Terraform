variable "project" {
  description = "The project ID."
  type        = string
}

variable "slo_name" {
  description = "The display name for this SLO"
  type        = string
}

variable "slo_id" {
  description = "Unique identifier for this SLO"
  type        = string
}

variable "slo_target" {
  description = "The fraction of service that must be good in order for this objective to be met."
  type        = number
}

variable "slo_compliance_period" {
  description = "The number of days for the SLO compliance period"
  type        = number
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
  type = object({
    enabled            = optional(bool)
    filter             = optional(string)
    duration_threshold = optional(string)
  })

  validation {
    condition     = var.deadman_alert.enabled != true || can(regex("metric.type", var.deadman_alert.filter))
    error_message = "The deadman_alert.filter value must be a valid metric filter."
  }
}

variable "pd_service_name" {
  description = "The PagerDuty service name that this alert should be routed to. This string is used to match the service name so it needs to be identical to the service name."
  type        = string
}
