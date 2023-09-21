terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.51.0"
    }
    google-beta = {
      version = "4.83.0"
    }
  }
}

resource "google_compute_network" "private_network" {
  provider = google-beta
  project  = var.project
  name     = var.network_name
}

resource "google_compute_global_address" "private_ip_address" {
  provider      = google-beta
  project       = var.project
  name          = var.network_ip
  purpose       = var.purpose
  address_type  = var.address_type
  prefix_length = 16
  network       = google_compute_network.private_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider = google-beta

  network                 = google_compute_network.private_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_sql_database_instance" "master" {
  name                 = var.master_db_name
  project              = var.project
  region               = var.region
  database_version     = var.database_version

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier                        = var.tier
    activation_policy           = var.activation_policy
    disk_autoresize             = var.disk_autoresize
    dynamic "backup_configuration" {
      for_each = [var.backup_configuration]
      content {

        point_in_time_recovery_enabled = lookup(backup_configuration.value, "point_in_time_recovery_enabled", var.backup_configuration.point_in_time_recovery_enabled)
        enabled            = lookup(backup_configuration.value, "enabled", var.backup_configuration.enabled)
        start_time         = lookup(backup_configuration.value, "start_time", var.backup_configuration.start_time)
      }
    }
    dynamic "ip_configuration" {
      for_each = [var.ip_configuration]
      content {

        ipv4_enabled    = lookup(ip_configuration.value, "ipv4_enabled", true)
        private_network = lookup(ip_configuration.value, "private_network", "${google_compute_network.private_network.id}")
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
        zone   = lookup(location_preference.value, "zone", "northamerica-northeast2-a")
      }
    }

    dynamic "maintenance_window" {
      for_each = [var.maintenance_window]
      content {

        day          = lookup(maintenance_window.value, "day", var.maintenance_window.day)
        hour         = lookup(maintenance_window.value, "hour", var.maintenance_window.hour)
        update_track = lookup(maintenance_window.value, "update_track", var.maintenance_window.update_track)
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


# Same Zone Replica instance configuration
resource "google_sql_database_instance" "replica_instance" {
  name             = "replica-instance"
  project          = var.project
  region           = var.region
  database_version = var.database_version

  replica_configuration {
    failover_target = false
  }

# Configure the replica-specific settings
  settings {
    tier              = var.replica_tier
    availability_type = var.replica_availability_type
    disk_size         = var.replica_disk_size
    backup_configuration {
      enabled = false
    }
    ip_configuration {
      ipv4_enabled    = true
      private_network = "${google_compute_network.private_network.id}"
    }
    location_preference {
      zone = "northamerica-northeast2-a"
    }
  }

  # Specify the replica-specific master instance name
  master_instance_name = "${google_sql_database_instance.master.name}"
}

# Different Zone Replica instance configuration
resource "google_sql_database_instance" "zonal-replica_instance" {
  name             = "zonal-replica-instance"
  project          = var.project
  region           = var.region
  database_version = var.database_version

  replica_configuration {
    failover_target = false
  }

# Configure the replica-specific settings
  settings {
    tier              = var.replica_tier
    availability_type = var.replica_availability_type
    disk_size         = var.replica_disk_size
    backup_configuration {
      enabled = false
    }
    ip_configuration {
      ipv4_enabled    = true
      private_network = "${google_compute_network.private_network.id}"
    }
    location_preference {
      zone = "northamerica-northeast2-b"
    }
  }

  # Specify the replica-specific master instance name
  master_instance_name = "${google_sql_database_instance.master.name}"
}

# Across Region Replica instance configuration
resource "google_sql_database_instance" "regional-replica_instance" {
  name             = "regional-replica-instance"
  project          = var.project
  region           = var.regional_replica_region
  database_version = var.database_version

  replica_configuration {
    failover_target = false
  }

# Configure the replica-specific settings
  settings {
    tier              = var.replica_tier  # Specify the replica's tier
    availability_type = var.replica_availability_type
    disk_size         = var.replica_disk_size
    backup_configuration {
      enabled = false
    }
    ip_configuration {
      ipv4_enabled    = true
      private_network = "${google_compute_network.private_network.id}"
    }
    location_preference {
      zone = "northamerica-northeast1-a"
    }
  }

  # Specify the replica-specific master instance name
  master_instance_name = "${google_sql_database_instance.master.name}"
}


resource "google_sql_database" "prod-db" {
  # count     = var.master_instance_name == "" ? 1 : 0
  depends_on = [
    google_sql_user.default
  ]
  name      = var.db_name
  project   = var.project
  instance  = google_sql_database_instance.master.name
  charset   = var.db_charset
  collation = var.db_collation
}

resource "google_sql_user" "default" {
  depends_on = [
    google_sql_database_instance.master
  ]
  name     = var.user_name
  project  = var.project
  instance = google_sql_database_instance.master.name
  password = var.user_password
}



