output "service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.text_analyzer.uri
}

output "repository_url" {
  description = "URL of the Artifact Registry repository"
  value       = google_artifact_registry_repository.repo.name
}