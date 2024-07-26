data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

data "google_service_account_id_token" "default" {
  target_service_account = google_service_account.vault.email
  target_audience        = google_cloud_run_service.default.status[0].url
  delegates              = []
  include_email          = true
}
