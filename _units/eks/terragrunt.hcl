# =============================================================================
# EKS UNIT - Terragrunt Wrapper for Local EKS Module
# =============================================================================
# This unit deploys an EKS cluster using the local self-managed module.
# All configuration comes from globals.hcl via the stack.
# =============================================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Use local EKS module
# terraform {
#   source = "${get_repo_root()}/modules/eks"
# }
terraform {
  source = "${get_terragrunt_dir()}"
}

# -----------------------------------------------------------------------------
# DEPENDENCIES
# -----------------------------------------------------------------------------

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id                   = "vpc-mock12345"
    private_subnets          = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
    private_subnet_arns      = ["arn:aws:ec2:us-east-1:123456789:subnet/subnet-mock1"]
    vpc_cidr_block           = "10.0.0.0/16"
    default_security_group_id = "sg-mock12345"
  }

  mock_outputs_merge_strategy_with_state = "shallow"
}

# -----------------------------------------------------------------------------
# INPUTS
# -----------------------------------------------------------------------------

inputs = {
  # Required inputs
  cluster_name    = "${values.project_name}-${values.environment}"
  cluster_version = values.cluster_version
  vpc_id          = dependency.vpc.outputs.vpc_id
  subnet_ids      = dependency.vpc.outputs.private_subnets

  # Region for provider
  aws_region = values.aws_region

  # Cluster endpoint access
  cluster_endpoint_public_access       = values.cluster_endpoint_public_access
  cluster_endpoint_private_access      = values.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = values.cluster_endpoint_public_access_cidrs

  # Cluster logging
  cluster_enabled_log_types     = values.cluster_enabled_log_types
  cluster_log_retention_in_days = values.cluster_log_retention_in_days

  # Encryption
  cluster_encryption_config       = values.cluster_encryption_config
  kms_key_deletion_window_in_days = values.kms_key_deletion_window_in_days

  # IRSA
  enable_irsa = values.enable_irsa

  # Pod Identity
  enable_pod_identity_agent = values.enable_pod_identity_agent

  # Authentication
  authentication_mode                         = values.authentication_mode
  bootstrap_cluster_creator_admin_permissions = values.bootstrap_cluster_creator_admin_permissions

  # Addons
  cluster_addons = values.cluster_addons

  # Node groups
  node_groups = values.node_groups

  # Additional security group rules
  cluster_security_group_additional_rules = values.cluster_security_group_additional_rules
  node_security_group_additional_rules    = values.node_security_group_additional_rules

  # Tags
  tags = merge(
    values.tags,
    {
      Component = "compute"
    }
  )
}
