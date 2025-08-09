terraform {
  backend "gcs" {
    bucket = "terraform-state-${var.project_id}"
    prefix = "text-analyzer"
  }
}