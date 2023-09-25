variable "project" {
  description = "The project to deploy to, if not set the default provider project is used."
  default     = "famous-modem-399417"
}

variable "region" {
  description = "Region for cloud resources"
  default     = "northamerica-northeast2"
}

variable "network_name" {
  description = "Name for private network"
  default     = "private-network"
}

variable "network_ip" {
  description = "Type of network ip"
  default     = "private-ip-address"
}

variable "purpose" {
  description = "Purpose for private network"
  default     = "VPC_PEERING"
}

variable "master_db_name" {
  description = "Name of Master database instance"
  default     = "postgres-db"
}

variable "address_type" {
  description = "Type of address"
  default     = "INTERNAL"
}

variable "database_version" {
  description = "The version of of the database. For example, `MYSQL_5_6` or `POSTGRES_9_6`."
  default     = "POSTGRES_15"
}

variable "master_instance_name" {
  description = "The name of the master instance to replicate"
  default     = "prod-db"
}

variable "tier" {
  description = "The machine tier (First Generation) or type (Second Generation). See this page for supported tiers and pricing: https://cloud.google.com/sql/pricing"
  default     = "db-custom-4-8192"
}

variable "db_name" {
  description = "Name of the default database to create"
  default     = "prod-db"
}

variable "db_charset" {
  description = "The charset for the default database"
  default     = "UTF8"
}

variable "db_collation" {
  description = "The collation for the default database. Example for MySQL databases: 'utf8_general_ci', and Postgres: 'en_US.UTF8'"
  default     = "en_US.UTF8"
}

variable "user_name" {
  description = "The name of the default user"
  default     = "admin"
}

variable "user_host" {
  description = "The host for the default user"
  default     = "%"
}

variable "user_password" {
  description = "The password for the default user. If not set, a random one will be generated and available in the generated_user_password output variable."
  default     = "postgres123"
}

variable "activation_policy" {
  description = "This specifies when the instance should be active. Can be either `ALWAYS`, `NEVER` or `ON_DEMAND`."
  default     = "ALWAYS"
}

variable "authorized_gae_applications" {
  description = "A list of Google App Engine (GAE) project names that are allowed to access this instance."
  default     = []
}

variable "disk_autoresize" {
  description = "Second Generation only. Configuration to increase storage size automatically."
  default     = true
}

variable "disk_size" {
  description = "Second generation only. The size of data disk, in GB. Size of a running instance cannot be reduced but can be increased."
  default     = 10
}

variable "disk_type" {
  description = "Second generation only. The type of data disk: `PD_SSD` or `PD_HDD`."
  default     = "PD_SSD"
}

variable "pricing_plan" {
  description = "First generation only. Pricing plan for this instance, can be one of `PER_USE` or `PACKAGE`."
  default     = "PER_USE"
}

variable "database_flags" {
  description = "List of Cloud SQL flags that are applied to the database server"
  default     = []
}

variable "backup_configuration" {
  description = "The backup_configuration settings subblock for the database setings"
  default     = {
    point_in_time_recovery_enabled = true
    enabled                        = true
    start_time                     = "01:00"
    binary_log_enabled             = true
    backup_location                = "northamerica-northeast2"
    log_retention_days             = 7
    retained_backups               = 9
  }
}

variable "ip_configuration" {
  description = "The ip_configuration settings subblock"
  default     = {}
}

variable "location_preference" {
  description = "The location_preference settings subblock"
  default     = {}
}

variable "maintenance_window" {
  description = "The maintenance_window settings subblock"
  default     = {
    day          = 6
    hour         = 20
    update_track = "stable"
  }
}

variable "insights_config" {
  description = "The insights config settings sublock"
  default     = {
    query_insights_enabled  = true
    query_string_length     = 1024
    record_application_tags = true
    record_client_address   = true
  }
}

variable "availability_type" {
  description = "This specifies whether a PostgreSQL instance should be set up for high availability (REGIONAL) or single zone (ZONAL)."
  default     = "REGIONAL"
}

variable "replica_tier" {
  description = "The tier for replica database"
  default     = "db-f1-micro"
}

variable "replica_availability_type" {
  description = "This specifies whether a PostgreSQL replica instance should be set up for high availability (REGIONAL) or single zone (ZONAL)."
  default     = "ZONAL"
}

variable "replica_disk_size" {
  description = "The disk size for replica database"
  default     = "10"
}

variable "regional_replica_region" {
  description = "The region for replica database instance"
  default     = "northamerica-northeast1"
}
