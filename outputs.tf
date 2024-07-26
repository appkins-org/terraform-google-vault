output "app_url" {
  value = google_cloud_run_service.default.status[0].url
}

output "service_account_email" {
  value = google_service_account.vault.email
}

output "id_token" {
  value     = data.google_service_account_id_token.default.id_token
  sensitive = true
}
