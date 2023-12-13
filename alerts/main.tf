#
# Multiwindow, Multi-Burn-Rate Alerts for SLOs
#
locals {
  alerts                      = var.additional_alerts == null ? local.default_alerts : (var.disable_default_alerts == true ? var.additional_alerts : merge(local.default_alerts, var.additional_alerts))
  slo_compliance_period_mins = var.slo_compliance_period * 24 * 60

  default_alerts = {
    default_alert1 = {
      desc         = "2% of the error budget burned in the last 1 hour",
      burn_rate    = format("%.2f", 0.02 * local.slo_compliance_period_mins / 60), # 13.44
      long_window  = 60,
      short_window = 5,
      severity     = "critical",
    }

    default_alert2 = {
      desc         = "5% of the error budget burned in the last 6 hours",
      burn_rate    = format("%.2f", 0.05 * local.slo_compliance_period_mins / (60 * 6)), # 5.6
      long_window  = 60 * 6,
      short_window = 30,
      severity     = "critical",
    }

    default_alert3 = {
      desc         = "4% of the error budget burned in the last 1 day",
      burn_rate    = format("%.2f", 0.04 * local.slo_compliance_period_mins / (60 * 24)), # 1.12
      long_window  = 60 * 24,
      short_window = 60 * 2,
      severity     = "warning",
    }
  }

  deadman_alert = defaults(var.deadman_alert, {
    enabled            = false
    duration_threshold = "300s"
    filter             = null
  })
}

resource "google_monitoring_alert_policy" "alert" {
  for_each = local.alerts

  enabled      = var.enable_alerts
  display_name = "SLO | ${var.slo_name} | ${each.value.desc} | ${var.project} | ${each.value.severity} | ${var.pd_service_name}"
  project      = var.project
  combiner     = "AND"

  # Long Window
  conditions {
    display_name = "Burn rate exceeded ${each.value.burn_rate} for the past ${each.value.long_window}m"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${var.slo_id}\", \"${each.value.long_window}m\")"
      threshold_value = each.value.burn_rate
      duration        = "0s"
      comparison      = "COMPARISON_GT"
    }
  }

  # Short Window
  conditions {
    display_name = "Burn rate exceeded ${each.value.burn_rate} for the past ${each.value.short_window}m"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${var.slo_id}\", \"${each.value.short_window}m\")"
      threshold_value = each.value.burn_rate
      duration        = "0s"
      comparison      = "COMPARISON_GT"
    }
  }

  notification_channels = var.alert_notification_channels
}

resource "google_monitoring_alert_policy" "deadman_alert" {
  count = local.deadman_alert.enabled == true ? 1 : 0

  enabled      = var.enable_alerts
  display_name = "SLO | ${var.slo_name} | Deadman | ${var.project} | critical | ${var.pd_service_name}"
  project      = var.project
  combiner     = "AND"

  conditions {
    display_name = "Deadman: No traffic for this SLO"
    condition_absent {
      filter   = local.deadman_alert.filter
      duration = local.deadman_alert.duration_threshold

      aggregations {
        alignment_period     = "60s"
        cross_series_reducer = "REDUCE_COUNT"
        per_series_aligner   = "ALIGN_RATE"
      }
    }
  }

  notification_channels = var.alert_notification_channels
}
