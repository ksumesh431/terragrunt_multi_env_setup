# =============================================================================
# ENVIRONMENT STACK - Reusable Multi-Component Pattern
# =============================================================================
# This stack deploys a complete environment: VPC + EKS + RDS + SQS queues
# It can be reused for different regions (US, EU) and tenant types.
#
# NOTE: This stack requires the repository to be a git repo (git init).
# The get_repo_root() function returns the absolute path to the repo root.
# =============================================================================

locals {
  # Absolute path to units directory
  units_path = "${get_repo_root()}/_units"
}

# -----------------------------------------------------------------------------
# VPC - Networking Foundation
# -----------------------------------------------------------------------------
unit "vpc" {
  source = "${local.units_path}/vpc"
  path   = "vpc"

  values = {
    project_name           = values.project_name
    environment            = values.environment
    aws_region             = values.aws_region
    cidr                   = values.vpc.cidr
    azs                    = values.vpc.azs
    private_subnets        = values.vpc.private_subnets
    public_subnets         = values.vpc.public_subnets
    database_subnets       = values.vpc.database_subnets
    enable_nat_gateway     = values.vpc.enable_nat_gateway
    single_nat_gateway     = values.vpc.single_nat_gateway
    one_nat_gateway_per_az = values.vpc.one_nat_gateway_per_az
    tags                   = values.tags
  }
}

# -----------------------------------------------------------------------------
# EKS - Kubernetes Cluster
# -----------------------------------------------------------------------------
unit "eks" {
  source = "${local.units_path}/eks"
  path   = "eks"

  values = {
    project_name = values.project_name
    environment  = values.environment
    aws_region   = values.aws_region
    tags         = values.tags

    # Cluster configuration
    cluster_version                      = values.eks.cluster_version
    cluster_endpoint_public_access       = values.eks.cluster_endpoint_public_access
    cluster_endpoint_private_access      = values.eks.cluster_endpoint_private_access
    cluster_endpoint_public_access_cidrs = values.eks.cluster_endpoint_public_access_cidrs

    # Logging
    cluster_enabled_log_types     = values.eks.cluster_enabled_log_types
    cluster_log_retention_in_days = values.eks.cluster_log_retention_in_days

    # Encryption
    cluster_encryption_config       = values.eks.cluster_encryption_config
    kms_key_deletion_window_in_days = values.eks.kms_key_deletion_window_in_days

    # IRSA and Pod Identity
    enable_irsa               = values.eks.enable_irsa
    enable_pod_identity_agent = values.eks.enable_pod_identity_agent

    # Authentication
    authentication_mode                         = values.eks.authentication_mode
    bootstrap_cluster_creator_admin_permissions = values.eks.bootstrap_cluster_creator_admin_permissions

    # Addons
    cluster_addons = values.eks.cluster_addons

    # Node groups
    node_groups = values.eks.node_groups

    # Security group rules
    cluster_security_group_additional_rules = values.eks.cluster_security_group_additional_rules
    node_security_group_additional_rules    = values.eks.node_security_group_additional_rules
  }
}

# -----------------------------------------------------------------------------
# RDS - PostgreSQL Database
# -----------------------------------------------------------------------------
unit "rds" {
  source = "${local.units_path}/rds"
  path   = "rds"

  values = {
    project_name                 = values.project_name
    environment                  = values.environment
    aws_region                   = values.aws_region
    engine                       = values.rds.engine
    engine_version               = values.rds.engine_version
    family                       = values.rds.family
    major_engine_version         = values.rds.major_engine_version
    instance_class               = values.rds.instance_class
    allocated_storage            = values.rds.allocated_storage
    max_allocated_storage        = values.rds.max_allocated_storage
    storage_type                 = values.rds.storage_type
    multi_az                     = values.rds.multi_az
    storage_encrypted            = values.rds.storage_encrypted
    deletion_protection          = values.rds.deletion_protection
    backup_retention_period      = values.rds.backup_retention_period
    backup_window                = values.rds.backup_window
    maintenance_window           = values.rds.maintenance_window
    skip_final_snapshot          = values.rds.skip_final_snapshot
    performance_insights_enabled = values.rds.performance_insights_enabled
    monitoring_interval          = values.rds.monitoring_interval
    db_name                      = values.rds.db_name
    db_username                  = values.rds.db_username
    db_port                      = values.rds.db_port
    tags                         = values.tags
  }
}

# -----------------------------------------------------------------------------
# SQS - Message Queues
# -----------------------------------------------------------------------------
# Orders Queue
unit "sqs-orders" {
  source = "${local.units_path}/sqs"
  path   = "sqs/orders"

  values = {
    project_name               = values.project_name
    environment                = values.environment
    aws_region                 = values.aws_region
    queue_name                 = "orders"
    visibility_timeout_seconds = values.sqs.visibility_timeout_seconds
    message_retention_seconds  = values.sqs.message_retention_seconds
    receive_wait_time_seconds  = values.sqs.receive_wait_time_seconds
    sqs_managed_sse_enabled    = values.sqs.sqs_managed_sse_enabled
    tags                       = values.tags
  }
}

# Notifications Queue
unit "sqs-notifications" {
  source = "${local.units_path}/sqs"
  path   = "sqs/notifications"

  values = {
    project_name               = values.project_name
    environment                = values.environment
    aws_region                 = values.aws_region
    queue_name                 = "notifications"
    visibility_timeout_seconds = values.sqs.visibility_timeout_seconds
    message_retention_seconds  = values.sqs.message_retention_seconds
    receive_wait_time_seconds  = values.sqs.receive_wait_time_seconds
    sqs_managed_sse_enabled    = values.sqs.sqs_managed_sse_enabled
    tags                       = values.tags
  }
}

# Events Queue
unit "sqs-events" {
  source = "${local.units_path}/sqs"
  path   = "sqs/events"

  values = {
    project_name               = values.project_name
    environment                = values.environment
    aws_region                 = values.aws_region
    queue_name                 = "events"
    visibility_timeout_seconds = values.sqs.visibility_timeout_seconds
    message_retention_seconds  = values.sqs.message_retention_seconds
    receive_wait_time_seconds  = values.sqs.receive_wait_time_seconds
    sqs_managed_sse_enabled    = values.sqs.sqs_managed_sse_enabled
    tags                       = values.tags
  }
}
