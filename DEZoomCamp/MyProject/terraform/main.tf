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
  credentials = file(var.credentials)
  project = "english-premier-league-417019"
  region  = "europe-west3"
  #projectid = 168789564321
}

resource "google_storage_bucket" "terraform-bucket-01" {
  name          = "english-premier-league-417019-terraform-bucket"
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

resource "google_service_account" "service_account" {
  account_id   = "english-premier-league-417019"
  display_name = "english-premier-league"
}
resource "google_service_account_key" "service_account" {
  service_account_id = google_service_account.service_account.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}
resource "local_file" "service_account" {
    content  = base64decode(google_service_account_key.service_account.private_key)
    filename = "english-premier-league-417019-b58bc74d4810.json"
}


resource "google_bigquery_dataset" "bigquery-01" {
  dataset_id = "english_premier_league_417019_bigquery"
  location   = "US"
  #location   = "EUROPE-WEST3"
}