resource "random_id" "vault" {
  byte_length = 2
}

resource "google_service_account" "vault" {
  project      = var.project
  account_id   = var.vault_service_account_id
  display_name = "Vault Service Account for KMS auto-unseal"
}

resource "google_storage_bucket" "vault" {
  name          = local.vault_storage_bucket_name
  project       = var.project
  location      = "US"
  force_destroy = var.bucket_force_destroy
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.vault.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.vault.email}"
}

# Create a KMS key ring
resource "google_kms_key_ring" "vault" {
  name     = local.vault_kms_keyring_name
  project  = var.project
  location = var.location
}

# Create a crypto key for the key ring, rotate daily
resource "google_kms_crypto_key" "vault" {
  name            = "${var.name}-key"
  key_ring        = google_kms_key_ring.vault.id
  rotation_period = var.vault_kms_key_rotation

  version_template {
    algorithm        = var.vault_kms_key_algorithm
    protection_level = var.vault_kms_key_protection_level
  }
}

# Add the service account to the Keyring
resource "google_kms_key_ring_iam_member" "vault" {
  key_ring_id = google_kms_key_ring.vault.id
  role        = "roles/owner"
  member      = "serviceAccount:${google_service_account.vault.email}"
}

resource "google_cloud_run_service" "default" {
  name                       = var.name
  project                    = var.project
  location                   = var.location
  autogenerate_revision_name = true

  metadata {
    namespace = var.project

    annotations = {
      "run.googleapis.com/launch-stage" = "BETA"
    }
  }

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"        = 1 # HA not Supported
        "run.googleapis.com/vpc-access-connector" = var.vpc_connector != "" ? var.vpc_connector : null
        # Hardcoded here after a change in the Cloud Run API response
        # "run.googleapis.com/sandbox" = "gvisor"
      }
    }
    spec {
      service_account_name  = google_service_account.vault.email
      container_concurrency = var.container_concurrency
      containers {
        # Specifying args seems to require the command / entrypoint
        image = "${var.vault_image}:${var.vault_version}"

        command = [
          "/bin/sh",
          "-c"
        ]

        args = [
          join(" && ", [
            "mkdir -p ${var.plugin_path}",
            "wget https://github.com/1Password/vault-plugin-secrets-onepassword/releases/download/v1.1.0/vault-plugin-secrets-onepassword_1.1.0_darwin_amd64.zip -O /tmp/vault.zip",
            "unzip -d /tmp /tmp/vault.zip",
            "mv /tmp/vault-plugin-secrets-onepassword_v1.1.0 ${var.plugin_path}/onepassword",
            "chmod +x ${var.plugin_path}/onepassword",
            "/usr/local/bin/docker-entrypoint.sh server"
          ])
        ]

        ports {
          name           = "h2c"
          container_port = 8080
        }

        startup_probe {
          period_seconds        = 240
          timeout_seconds       = 240
          failure_threshold     = 3
          initial_delay_seconds = 15

          tcp_socket {
            port = 8080
          }
        }

        env {
          name  = "SKIP_SETCAP"
          value = "true"
        }

        env {
          name  = "VAULT_LOCAL_CONFIG"
          value = local.vault_config
        }

        env {
          name  = "VAULT_API_ADDR"
          value = var.vault_api_addr
        }

        resources {
          limits = {
            cpu    = "1000m"
            memory = "256Mi"
          }
          requests = {}
        }
      }
    }
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.default.location
  project  = google_cloud_run_service.default.project
  service  = google_cloud_run_service.default.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

output "app_url" {
  value = google_cloud_run_service.default.status[0].url
}

output "service_account_email" {
  value = google_service_account.vault.email
}
