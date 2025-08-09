terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  
  disable_on_destroy = false
}

# Artifact Registry repository
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "text-analyzer"
  description   = "Docker repository for text analyzer"
  format        = "DOCKER"
  
  depends_on = [google_project_service.apis]
}

# Service account for Cloud Run
resource "google_service_account" "cloudrun_sa" {
  account_id   = "text-analyzer-sa"
  display_name = "Text Analyzer Service Account"
  description  = "Service account for Cloud Run text analyzer service"
}

# Cloud Run service (internal only)
resource "google_cloud_run_v2_service" "text_analyzer" {
  name     = "text-analyzer"
  location = var.region
  
  template {
    service_account = google_service_account.cloudrun_sa.email
    
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}/text-analyzer:${var.image_tag}"
      
      ports {
        container_port = 8080
      }
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }
  
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
  
  # Make service internal only
  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  
  depends_on = [google_project_service.apis]
}

# IAM policy to restrict access (internal only)
resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_v2_service.text_analyzer.location
  project  = google_cloud_run_v2_service.text_analyzer.project
  service  = google_cloud_run_v2_service.text_analyzer.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:${google_service_account.cloudrun_sa.email}",
    ]
  }
}