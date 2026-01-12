# =============================================================================
# RDS UNIT - AWS RDS Module Wrapper (PostgreSQL)
# =============================================================================
# Uses the official AWS RDS Terraform module
# Source: https://registry.terraform.io/modules/terraform-aws-modules/rds/aws
# =============================================================================

terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.4.0"
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# -----------------------------------------------------------------------------
# DEPENDENCIES
# -----------------------------------------------------------------------------
dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id                         = "vpc-mock-12345"
    database_subnet_group_name     = "mock-db-subnet-group"
    private_subnets_cidr_blocks    = ["10.0.1.0/24", "10.0.2.0/24"]
    default_security_group_id      = "sg-mock-12345"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# -----------------------------------------------------------------------------
# INPUTS
# -----------------------------------------------------------------------------
inputs = {
  # Provider configuration
  aws_region = values.aws_region

  identifier = "${values.project_name}-${values.environment}-postgres"

  # Engine configuration
  engine               = values.engine
  engine_version       = values.engine_version
  family               = values.family
  major_engine_version = values.major_engine_version
  instance_class       = values.instance_class

  # Storage
  allocated_storage     = values.allocated_storage
  max_allocated_storage = values.max_allocated_storage
  storage_type          = values.storage_type
  storage_encrypted     = values.storage_encrypted

  # Database settings from globals
  db_name  = values.db_name
  username = values.db_username
  port     = values.db_port

  # Automated password management via Secrets Manager
  manage_master_user_password = true

  # High availability
  multi_az = values.multi_az

  # Network
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  vpc_security_group_ids = []  # Will be created by module
  publicly_accessible    = false

  # Create security group
  create_db_subnet_group = false  # Use VPC's subnet group
  
  # Backup configuration
  backup_retention_period = values.backup_retention_period
  backup_window           = values.backup_window
  maintenance_window      = values.maintenance_window
  
  # Prevent accidental deletion
  deletion_protection = values.deletion_protection
  skip_final_snapshot = values.skip_final_snapshot
  final_snapshot_identifier_prefix = "${values.project_name}-${values.environment}-final"

  # Performance insights
  performance_insights_enabled = values.performance_insights_enabled
  
  # Monitoring from globals
  monitoring_interval = values.monitoring_interval
  create_monitoring_role = values.monitoring_interval > 0 ? true : false
  monitoring_role_name   = values.monitoring_interval > 0 ? "${values.project_name}-${values.environment}-rds-monitoring" : null

  # Parameter group - use family from globals
  parameter_group_name = "${values.project_name}-${values.environment}-${values.family}"
  create_db_parameter_group = true
  parameters = [
    {
      name  = "log_connections"
      value = "1"
    },
    {
      name  = "log_disconnections"
      value = "1"
    }
  ]

  # Tags
  tags = merge(
    values.tags,
    {
      Component = "database"
    }
  )
}
