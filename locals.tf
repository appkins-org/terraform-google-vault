locals {
  vault_config = jsonencode(
    {
      plugin_directory = var.plugin_directory
      storage = {
        gcs = {
          bucket     = local.vault_storage_bucket_name
          ha_enabled = "false"
        }
      }
      seal = {
        gcpckms = {
          project    = var.project,
          region     = var.location,
          key_ring   = local.vault_kms_keyring_name,
          crypto_key = google_kms_crypto_key.vault.name
        }
      }
      default_lease_ttl = "168h",
      max_lease_ttl     = "720h",
      disable_mlock     = "true",
      listener = {
        tcp = {
          address     = "0.0.0.0:8080",
          tls_disable = "1"
        }
      }
      ui = var.vault_ui
    }
  )
  vault_kms_keyring_name    = var.vault_kms_keyring_name != "" ? var.vault_kms_keyring_name : "${var.name}-${lower(random_id.vault.hex)}-kr"
  vault_storage_bucket_name = var.vault_storage_bucket_name != "" ? var.vault_storage_bucket_name : "${var.name}-${lower(random_id.vault.hex)}-bucket"
}
