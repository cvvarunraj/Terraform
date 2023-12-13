resource "google_logging_metric" "ein_viewer_time_to_show_anchor_study_first_image" {
  name        = "ein_viewer_time_to_show_anchor_study_first_image"
  description = "EIN Viewer client TimeToShowAnchorStudyFirstImage span"
  filter      = <<EOT
        logName:logs/ViewerAppSpans
        AND severity="NOTICE"
        AND jsonPayload.msg.name="McK.VS.ViewerApp.Span.TimeToShowAnchorStudyFirstImage"
        AND resource.type="global"
        AND -jsonPayload.tenantId="qdeVPxPQ"
        EOT
  project     = "ei-cs-prod-ein"
  bucket_options {
    exponential_buckets {
      num_finite_buckets = 15
      growth_factor      = 2.0
      scale              = 1
    }
  }

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    unit        = "ms"
  }

  value_extractor = "EXTRACT(jsonPayload.msg.latency)"
}

resource "google_logging_metric" "ein_viewer_time_to_show_timeline" {
  name        = "ein_viewer_time_to_show_timeline"
  description = "EIN Viewer client TimeToShowTimeline span"
  filter      = <<EOT
        logName:logs/ViewerAppSpans
        AND severity="NOTICE"
        AND jsonPayload.msg.name="McK.VS.ViewerApp.Span.TimeToShowTimeline"
        AND resource.type="global"
        AND -jsonPayload.tenantId="qdeVPxPQ"
  EOT
  project     = "ei-cs-prod-ein"
  bucket_options {
    exponential_buckets {
      num_finite_buckets = 15
      growth_factor      = 2.0
      scale              = 1
    }
  }
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    unit        = "ms"
  }

  value_extractor = "EXTRACT(jsonPayload.msg.latency)"
}

resource "google_logging_metric" "ein_viewer_view_patient_record" {
  name        = "ein_viewer_view_patient_record"
  description = "EIN Viewer client ViewPatientRecord"
  filter      = <<EOT
        (logName:logs/AuditEvent OR logName:logs/ViewerAppSpans)
        AND resource.type="global"
        AND -jsonPayload.tenantId="qdeVPxPQ"
  EOT
  project     = "ei-cs-prod-ein"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key         = "hipaaEvent_type"
      value_type  = "STRING"
      description = "Event type"
    }
    labels {
      key         = "name"
      value_type  = "STRING"
      description = "TimeToShowAnchorStudyFirstImage msg name"
    }
  }

  label_extractors = {
    "name"            = "EXTRACT(jsonPayload.msg.name)"
    "hipaaEvent_type" = "EXTRACT(labels.hipaaEvent_type)"
  }
}

resource "google_logging_metric" "ein_viewer_reports_opened" {
  name        = "ein_viewer_reports_opened"
  description = "EIN Viewer client Reports_Opened"
  filter      = <<EOT
    resource.type="k8s_container"
    AND resource.labels.namespace_name="ipi-diagnosticreportaccess"
    AND jsonPayload.msg.url:"/v1/reports?"
    AND jsonPayload.msg.desc="END request"
  EOT
  project     = "ei-cs-prod-ein"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key         = "status"
      value_type  = "INT64"
      description = "The HTTP status code"
    }
  }

  label_extractors = {
    "status" = "EXTRACT(jsonPayload.msg.status)"
  }
}

resource "google_logging_metric" "ein_viewer_studies_opened_availability" {
  name        = "ein_viewer_studies_opened_availaibility"
  description = "EIN Viewer Studies Opened Availability"
  filter      = <<EOT
      logName:"projects/ei-cs-prod-ein/logs/ViewerAppWorkflow"
      AND jsonPayload.operation="open study"
      AND -jsonPayload.tenantId="qdeVPxPQ"
      AND -jsonPayload.tenantId="wDPgNepG"
      AND -jsonPayload.error_type="StudyNotFound"
      AND -jsonPayload.error_type="NoAvailableStudy"
  EOT
  project     = "ei-cs-prod-ein"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key         = "status"
      value_type  = "STRING"
      description = "Event type"
    }
  }

  label_extractors = {
    "status" = "EXTRACT(jsonPayload.status)"
  }
}

resource "google_logging_metric" "ein_viewer_patient_search_latency" {
  name        = "ein_viewer_patient_search_latency"
  description = "EIN Viewer Patient Search Latency"
  filter      = <<-EOT
        resource.type="gce_instance"
        AND logName="projects/ei-cs-prod-ein/logs/vsDal"
        AND jsonPayload.logger:"McK.VS.DAL.WebAPI.Controllers.PatientController"
        AND "[Perf Patient Search] TOOK"
    EOT

  project         = "ei-cs-prod-ein"
  value_extractor = "REGEXP_EXTRACT(jsonPayload.message, \"(\\\\d.\\\\d\\\\d\\\\d)\")"

  bucket_options {

    exponential_buckets {
      num_finite_buckets = 15
      growth_factor      = 2
      scale              = 0.01
    }
  }

  metric_descriptor {
    metric_kind = "DELTA"
    unit        = "s"
    value_type  = "DISTRIBUTION"

    labels {
      key        = "performance_metric"
      value_type = "INT64"
    }
  }

  label_extractors = {
    "performance_metric" = "REGEXP_EXTRACT(jsonPayload.message, \"(\\\\d.\\\\d\\\\d\\\\d)\")"
  }
}

module "slo_viewer_availability_2" {
  source = "./modules/slo/good_total_ratio"

  project                     = "ei-cs-prod-ein"
  service                     = google_monitoring_custom_service.ei_cs_prod_ein_ein_viewer.service_id
  slo_name                    = "Reports Opened Availability (Client): 95% success rate"
  slo_target                  = 0.95
  good_events_filter          = <<-EOT
    metric.type="logging.googleapis.com/user/${google_logging_metric.ein_viewer_reports_opened.id}" 
    AND resource.type="k8s_container"
		AND metric.label.status<"400"
  EOT
  total_events_filter         = <<-EOT
    metric.type="logging.googleapis.com/user/${google_logging_metric.ein_viewer_reports_opened.id}"
    AND resource.type="k8s_container"
  EOT
  alert_notification_channels = [google_monitoring_notification_channel.pd-ei_cs_prod_ein-ein_viewer_slos[0].name]
  pd_service_name             = data.terraform_remote_state.pagerduty.outputs.slo_technical_services.ein_viewer_slo
  enable_alerts               = true
}

module "slo_viewer_availability_3" {
  source = "./modules/slo/good_total_ratio"

  project                     = "ei-cs-prod-ein"
  service                     = google_monitoring_custom_service.ei_cs_prod_ein_ein_viewer.service_id
  slo_name                    = "Studies Opened Availability (Client): 95% success rate"
  slo_target                  = 0.95
  good_events_filter          = <<-EOT
    metric.type="logging.googleapis.com/user/${google_logging_metric.ein_viewer_studies_opened_availability.id}" 
    AND resource.type="global"
    AND metric.label.status="success"
  EOT
  total_events_filter         = <<-EOT
    metric.type="logging.googleapis.com/user/${google_logging_metric.ein_viewer_studies_opened_availability.id}" 
    AND resource.type="global"
  EOT
  alert_notification_channels = [google_monitoring_notification_channel.pd-ei_cs_prod_ein-ein_viewer_slos[0].name]
  pd_service_name             = data.terraform_remote_state.pagerduty.outputs.slo_technical_services.ein_viewer_slo
  enable_alerts               = true
}

module "slo_viewer_latency_2" {
  source                      = "./modules/slo/distribution_cut"
  project                     = "ei-cs-prod-ein"
  service                     = google_monitoring_custom_service.ei_cs_prod_ein_ein_viewer.service_id
  slo_name                    = "Time To Show Timeline Latency (Client): 95% <= 10s "
  slo_target                  = 0.95
  sli_range_max               = 10000
  distribution_filter         = <<-EOT
    metric.type="logging.googleapis.com/user/${google_logging_metric.ein_viewer_time_to_show_timeline.id}"
    AND resource.type="global"
  EOT
  alert_notification_channels = [google_monitoring_notification_channel.pd-ei_cs_prod_ein-ein_viewer_slos[0].name]
  pd_service_name             = data.terraform_remote_state.pagerduty.outputs.slo_technical_services.ein_viewer_slo
  enable_alerts               = true
}

module "slo_viewer_latency_3" {
  source                      = "./modules/slo/distribution_cut"
  project                     = "ei-cs-prod-ein"
  service                     = google_monitoring_custom_service.ei_cs_prod_ein_ein_viewer.service_id
  slo_name                    = "Time To Show Anchor Study First Image Latency (Client): 50% <= 6s "
  slo_target                  = 0.50
  sli_range_max               = 6000
  distribution_filter         = <<-EOT
    metric.type="logging.googleapis.com/user/${google_logging_metric.ein_viewer_time_to_show_anchor_study_first_image.id}"
    AND resource.type="global"
  EOT
  alert_notification_channels = [google_monitoring_notification_channel.pd-ei_cs_prod_ein-ein_viewer_slos[0].name]
  pd_service_name             = data.terraform_remote_state.pagerduty.outputs.slo_technical_services.ein_viewer_slo
  enable_alerts               = true
}

module "slo_viewer_latency_4" {
  source                      = "./modules/slo/distribution_cut"
  project                     = "ei-cs-prod-ein"
  service                     = google_monitoring_custom_service.ei_cs_prod_ein_ein_viewer.service_id
  slo_name                    = "Time To Show Timeline Latency (Client): 50% <= 4s "
  slo_target                  = 0.50
  sli_range_max               = 4000
  distribution_filter         = <<-EOT
    metric.type="logging.googleapis.com/user/${google_logging_metric.ein_viewer_time_to_show_timeline.id}"
    AND resource.type="global"
  EOT
  alert_notification_channels = [google_monitoring_notification_channel.pd-ei_cs_prod_ein-ein_viewer_slos[0].name]
  pd_service_name             = data.terraform_remote_state.pagerduty.outputs.slo_technical_services.ein_viewer_slo
  enable_alerts               = true
}

#https://jira.healthcareit.net/browse/ICO-5753
module "slo_viewer_latency_5" {
  source                      = "./modules/slo/distribution_cut"
  project                     = "ei-cs-prod-ein"
  service                     = google_monitoring_custom_service.ei_cs_prod_ein_ein_viewer.service_id
  slo_name                    = "Time To Show Anchor Study First Image Latency (Client): 95% <= 10s"
  slo_target                  = 0.95
  sli_range_max               = 10000
  distribution_filter         = <<-EOT
    metric.type="logging.googleapis.com/user/${google_logging_metric.ein_viewer_time_to_show_anchor_study_first_image.id}"
    AND resource.type="global"
  EOT
  alert_notification_channels = [google_monitoring_notification_channel.pd-ei_cs_prod_ein-ein_viewer_slos[0].name]
  pd_service_name             = data.terraform_remote_state.pagerduty.outputs.slo_technical_services.ein_viewer_slo
  enable_alerts               = false
}

#https://jira.healthcareit.net/browse/ICO-5303

module "slo_viewer_latency_6" {
  source                      = "./modules/slo/distribution_cut"
  project                     = "ei-cs-prod-ein"
  service                     = google_monitoring_custom_service.ei_cs_prod_ein_ein_viewer.service_id
  slo_name                    = "Patient Search Latency (Client): 95% <= 0.1s "
  slo_target                  = 0.95
  sli_range_max               = 0.1
  distribution_filter         = <<-EOT
    metric.type="logging.googleapis.com/user/${google_logging_metric.ein_viewer_patient_search_latency.id}"
    AND resource.type="gce_instance"
  EOT
  alert_notification_channels = [google_monitoring_notification_channel.pd-ei_cs_prod_ein-ein_viewer_slos[0].name]
  pd_service_name             = data.terraform_remote_state.pagerduty.outputs.slo_technical_services.ein_viewer_slo
  enable_alerts               = false
}

module "slo_viewer_latency_7" {
  source                      = "./modules/slo/distribution_cut"
  project                     = "ei-cs-prod-ein"
  service                     = google_monitoring_custom_service.ei_cs_prod_ein_ein_viewer.service_id
  slo_name                    = "Patient Search Latency (Client): 50% <= 0.070s "
  slo_target                  = 0.50
  sli_range_max               = 0.070
  distribution_filter         = <<-EOT
    metric.type="logging.googleapis.com/user/${google_logging_metric.ein_viewer_patient_search_latency.id}"
    AND resource.type="gce_instance"
  EOT
  alert_notification_channels = [google_monitoring_notification_channel.pd-ei_cs_prod_ein-ein_viewer_slos[0].name]
  pd_service_name             = data.terraform_remote_state.pagerduty.outputs.slo_technical_services.ein_viewer_slo
  enable_alerts               = false
}