terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
# Credentials only needs to be set if you do not have the GOOGLE_APPLICATION_CREDENTIALS set
  project = "theta-byte-412611"
  region  = "europe-west3"
}

resource "google_storage_bucket" "terraform-bucket-01" {
  name          = "theta-byte-412611-terraform-bucket"
  location      = "EUROPE-WEST3"

  # Optional, but recommended settings:
  storage_class = "STANDARD"
  uniform_bucket_level_access = true

  versioning {
    enabled     = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30  // days
    }
  }

  force_destroy = true
}

resource "google_bigquery_dataset" "terraform-bigquery-dataset-01" {
  dataset_id = "theta_byte_412611_terraform_bigquery_dataset_01"
  location   = "EUROPE-WEST3"
}