terraform {
  backend "gcs" {
    bucket      = "tf-state-dev-123"
    prefix      = "terraform/state"
    credentials = "sa-dev-credential.json"
  }
}