terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.51.0"
    }
  }
}


resource "google_sql_database_instance" "master" {
  name                 = "postgres-db"
  project              = var.project
  region               = var.region
  database_version     = var.database_version
  master_instance_name = var.master_instance_name

  settings {
    tier                        = var.tier
    activation_policy           = var.activation_policy
    disk_autoresize             = var.disk_autoresize
    dynamic "backup_configuration" {
      for_each = [var.backup_configuration]
      content {

        point_in_time_recovery_enabled = lookup(backup_configuration.value, "point_in_time_recovery_enabled", true)
        enabled            = lookup(backup_configuration.value, "enabled", true)
        start_time         = lookup(backup_configuration.value, "start_time", "05:00")
      }
    }
    dynamic "ip_configuration" {
      for_each = [var.ip_configuration]
      content {

        ipv4_enabled    = lookup(ip_configuration.value, "ipv4_enabled", true)
        private_network = lookup(ip_configuration.value, "private_network", null)
        require_ssl     = lookup(ip_configuration.value, "require_ssl", null)

        dynamic "authorized_networks" {
          for_each = lookup(ip_configuration.value, "authorized_networks", [])
          content {
            expiration_time = lookup(authorized_networks.value, "expiration_time", null)
            name            = lookup(authorized_networks.value, "name", null)
            value           = lookup(authorized_networks.value, "value", null)
          }
        }
      }
    }
    dynamic "location_preference" {
      for_each = [var.location_preference]
      content {
        zone                   = lookup(location_preference.value, "zone", "northamerica-northeast2-a")
      }
    }
    disk_size        = var.disk_size
    disk_type        = var.disk_type
    pricing_plan     = var.pricing_plan
    availability_type = var.availability_type
  }

  timeouts {
    create = "60m"
    delete = "2h"
  }
}


# Replica instance configuration
resource "google_sql_database_instance" "replica_instance" {
  name             = "replica-instance"
  project          = var.project
  region           = var.region
  database_version = var.database_version

  # Configure the replica-specific settings
  settings {
    tier              = "db-f1-micro"  # Specify the replica's tier
    activation_policy = "ALWAYS"

  }

  # Specify the replica-specific master instance name
  master_instance_name = "${google_sql_database_instance.master.name}"
}


resource "google_sql_database" "prod-db" {
  count     = var.master_instance_name == "" ? 1 : 0
  name      = var.db_name
  project   = var.project
  instance  = google_sql_database_instance.master.name
  charset   = var.db_charset
  collation = var.db_collation
}

resource "google_sql_user" "default" {
  name     = var.user_name
  project  = var.project
  instance = google_sql_database_instance.master.name
  host     = var.user_host
  password = var.user_password
}
