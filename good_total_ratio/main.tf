locals {
  # For this SLO type, the deadman filter will default to the total events filter
  deadman_alert = defaults(var.deadman_alert, {
    filter = var.total_events_filter
  })
}

resource "google_monitoring_slo" "slo" {
  service      = var.service
  display_name = var.slo_name
  project      = var.project

  goal                = var.slo_target
  rolling_period_days = var.slo_compliance_period

  request_based_sli {
    good_total_ratio {
      good_service_filter  = var.good_events_filter
      bad_service_filter   = var.bad_events_filter
      total_service_filter = var.total_events_filter
    }
  }
}

module "alerts" {
  source = "../alerts"

  project                     = var.project
  slo_name                    = var.slo_name
  slo_id                      = google_monitoring_slo.slo.id
  slo_target                  = var.slo_target
  slo_compliance_period       = var.slo_compliance_period
  additional_alerts           = var.additional_alerts
  alert_notification_channels = var.alert_notification_channels
  pd_service_name             = var.pd_service_name
  enable_alerts               = var.enable_alerts
  deadman_alert               = local.deadman_alert
  disable_default_alerts      = var.disable_default_alerts
}
