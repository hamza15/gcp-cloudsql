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

# Simple network, auto-creates subnetworks
resource "google_compute_network" "private_network" {
  provider = google-beta
  project  = var.project
  name     = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "shared_access_subnet" {
  provider      = google-beta
  name          = "shared-access-subnet"
  ip_cidr_range = "10.0.0.0/28"
  project  = var.project
  region        = "northamerica-northeast2"
  network       = google_compute_network.private_network.id
  depends_on = [
    google_compute_network.private_network
  ]
}

resource "google_compute_subnetwork" "subnet-2" {
  provider      = google-beta
  name          = "shared-access-subnet-2"
  ip_cidr_range = "10.0.0.16/28"
  project  = var.project
  region        = "northamerica-northeast2"
  network       = google_compute_network.private_network.id
  depends_on = [
    google_compute_network.private_network
  ]
}

# Reserve global internal address range for the peering
resource "google_compute_global_address" "private_ip_address" {
  provider      = google-beta
  project       = var.project
  name          = var.network_ip
  purpose       = var.purpose
  address_type  = var.address_type
  prefix_length = 16
  network       = google_compute_network.private_network.id
}

# Establish VPC network peering connection using the reserved address range
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
  deletion_protection = false

  settings {
    tier                        = var.tier
    
    activation_policy           = var.activation_policy
    disk_autoresize             = var.disk_autoresize
    dynamic "backup_configuration" {
      for_each = [var.backup_configuration]
      content {

        point_in_time_recovery_enabled = lookup(backup_configuration.value, "point_in_time_recovery_enabled", var.backup_configuration.point_in_time_recovery_enabled)
        enabled                        = lookup(backup_configuration.value, "enabled", var.backup_configuration.enabled)
        start_time                     = lookup(backup_configuration.value, "start_time", var.backup_configuration.start_time)
        # binary_log_enabled             = lookup(backup_configuration.value, "binary_log_enabled", var.backup_configuration.binary_log_enabled)
        location                       = lookup(backup_configuration.value, "location", var.backup_configuration.backup_location)
        transaction_log_retention_days = lookup(backup_configuration.value, "log_retention_days", var.backup_configuration.log_retention_days)
      
      dynamic "backup_retention_settings" {
        for_each = lookup(backup_configuration.value, "backup_retention_settings", [])
        content {
          retained_backups = lookup(backup_retention_settings.value, "retained_backups", var.backup_configuration.retained_backups)
        }
      }
      }
    }
    dynamic "ip_configuration" {
      for_each = [var.ip_configuration]
      content {

        ipv4_enabled    = lookup(ip_configuration.value, "ipv4_enabled", false)
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

    dynamic "insights_config" {
      for_each = [var.insights_config]
      content {
        query_insights_enabled  = lookup(insights_config.value, "", var.insights_config.query_insights_enabled)
        query_string_length     = lookup(insights_config.value, "", var.insights_config.query_string_length)
        record_application_tags = lookup(insights_config.value, "", var.insights_config.record_application_tags)
        record_client_address   = lookup(insights_config.value, "", var.insights_config.record_client_address)
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
  deletion_protection = false

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
      ipv4_enabled    = false
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
      ipv4_enabled    = false
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

  deletion_protection = false
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
      ipv4_enabled    = false
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
