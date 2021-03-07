provider "google" {
  project     = var.project_id
  credentials = "sa-dev-credential.json"
}

resource "google_compute_network" "cpos-dev-vpc" {
  name                    = "${var.dev-cpos}-vpc-1"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "cpos-dev-vpc-sn-1" {
  name                     = "${var.dev-cpos}-vpc-sn-1"
  ip_cidr_range            = var.cpos-dev-cidr-range
  region                   = var.location
  private_ip_google_access = true
  network                  = google_compute_network.cpos-dev-vpc.id
}

resource "google_compute_firewall" "cpos-dev-vpc-firewall-ssh" {
  name    = "${var.dev-cpos}-ssh"
  network = google_compute_network.cpos-dev-vpc.name
  direction               = "INGRESS"
  priority                = 1000
  source_ranges = var.cpos-dev-iap-range-ssh
  allow {
    protocol = "tcp"
    ports    = var.cpos-dev-ssh
  }

  source_tags = ["cpos-dev-gitlab-runner"]
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.dev-cpos}-cloudsql-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16

  network = google_compute_network.cpos-dev-vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {

  network                 = google_compute_network.cpos-dev-vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

################################################################3

resource "google_sql_database_instance" "cpos-dev-cloudsql" {

  name             = "${var.dev-cpos}-db-apps-1"
  database_version = "POSTGRES_11"

  deletion_protection = false
  region              = "us-central1"

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    activation_policy           = "ALWAYS"
    authorized_gae_applications = []
    availability_type           = "REGIONAL"
    crash_safe_replication      = false
    disk_autoresize             = true
    disk_size                   = 10
    disk_type                   = "PD_SSD"
    replication_type            = "SYNCHRONOUS"
    tier                        = "db-custom-1-3840"
    user_labels = {
      "env" = "development"
    }

    backup_configuration {
      binary_log_enabled             = false
      enabled                        = true
      location                       = "us-central1"
      point_in_time_recovery_enabled = true
      start_time                     = "18:00"
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.cpos-dev-vpc.id
      require_ssl     = false
    }

    location_preference {
      zone = "us-central1-f"
    }

    maintenance_window {
      day  = 6
      hour = 16
    }
  }
}

#################################################################

resource "google_sql_database" "database" {
  name     = "${var.dev-cpos}-db"
  instance = google_sql_database_instance.cpos-dev-cloudsql.name
}

resource "google_sql_user" "users" {
  name     = "${var.dev-cpos}-user"
  instance = google_sql_database_instance.cpos-dev-cloudsql.name
  password = "kqhkiG9w0BAQsFADB3MS0w"
}

### TO connect linux cmd ####
### psql -h 10.86.0.2 -d dev-cpos-db -U dev-cpos-user ####

#################################################################

output "cloudsql-connect" {

  value = google_sql_database_instance.cpos-dev-cloudsql.connection_name
}

##################################################################

resource "google_cloud_run_service" "cloud-run-demo" {
  name     = "cloudrun-srv"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "1000"
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.cpos-dev-cloudsql.connection_name
        "run.googleapis.com/client-name"        = "terraform"
        "run.googleapis.com/sandbox"            = "gvisor"
      }
    }
  }
  autogenerate_revision_name = true
}

