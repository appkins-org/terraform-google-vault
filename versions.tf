terraform {
  required_providers {
    google = {
      source = "hashicorp/google-beta"
    }
    random = {
      source = "hashicorp/random"
    }
  }
  required_version = ">= 1.4"
}
