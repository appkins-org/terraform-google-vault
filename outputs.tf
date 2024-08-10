output "app_url" {
  value = google_cloud_run_service.default.status[0].url
}

output "service_account_email" {
  value = google_service_account.vault.email
}
