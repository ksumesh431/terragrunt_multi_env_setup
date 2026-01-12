# =============================================================================
# LIVE DEPLOYMENT - ROOT ORCHESTRATOR
# =============================================================================
# This is the main entry point for deploying all infrastructure.
# It orchestrates multi-tenant (US, EU) and single-tenant deployments.
#
# Commands:
#   terragrunt stack generate    - Generate all stacks
#   terragrunt stack run apply   - Deploy all stacks
#   terragrunt run --all plan    - Plan all units
# =============================================================================

# Load global configuration (single source of truth)
locals {
  globals = read_terragrunt_config(find_in_parent_folders("globals.hcl")).locals
}

# =============================================================================
# MULTI-TENANT REGIONS
# =============================================================================

# -----------------------------------------------------------------------------
# US REGION - Multi-tenant shared infrastructure
# -----------------------------------------------------------------------------
stack "us" {
  source = "../_stacks/environment"
  path   = "us"

  values = {
    project_name = local.globals.project_name
    environment  = local.globals.regions.us.environment
    aws_region   = local.globals.regions.us.aws_region

    # Component configurations from globals
    vpc = local.globals.vpc.us
    eks = local.globals.eks.us
    rds = local.globals.rds.us
    sqs = local.globals.sqs.us

    # Tags for this region
    tags = merge(
      local.globals.common_tags,
      local.globals.regions.us.compliance_tags,
      {
        Region      = "us"
        Environment = local.globals.regions.us.environment
        TenantType  = "multi-tenant"
      }
    )
  }
}

# -----------------------------------------------------------------------------
# EU REGION - GDPR-isolated infrastructure
# -----------------------------------------------------------------------------
# IMPORTANT: This region is completely isolated for GDPR compliance.
# No data (databases, queues, logs) should flow outside eu-west-1.
stack "eu" {
  source = "../_stacks/environment"
  path   = "eu"

  values = {
    project_name = local.globals.project_name
    environment  = local.globals.regions.eu.environment
    aws_region   = local.globals.regions.eu.aws_region

    # Component configurations from globals
    vpc = local.globals.vpc.eu
    eks = local.globals.eks.eu
    rds = local.globals.rds.eu
    sqs = local.globals.sqs.eu

    # Tags for GDPR region - includes compliance tags
    tags = merge(
      local.globals.common_tags,
      local.globals.regions.eu.compliance_tags,  # GDPR, DataResidency tags
      {
        Region      = "eu"
        Environment = local.globals.regions.eu.environment
        TenantType  = "multi-tenant"
      }
    )
  }
}

# =============================================================================
# SINGLE-TENANT DEPLOYMENTS
# =============================================================================
# Each single-tenant customer gets fully isolated infrastructure:
# - Dedicated VPC (no shared networking)
# - Dedicated EKS cluster
# - Dedicated RDS instance
# - Dedicated SQS queues

# -----------------------------------------------------------------------------
# ACME Corporation - Enterprise Single-Tenant
# -----------------------------------------------------------------------------
stack "single-tenant-acme-corp" {
  source = "../_stacks/environment"
  path   = "single-tenant/acme-corp"

  values = {
    project_name = "acme-corp"  # Tenant-specific naming
    environment  = local.globals.single_tenants["acme-corp"].environment
    aws_region   = local.globals.single_tenants["acme-corp"].region

    # Single-tenant optimized configurations
    vpc = merge(
      local.globals.vpc.single_tenant,
      {
        cidr = local.globals.single_tenants["acme-corp"].vpc_cidr
      }
    )
    eks = local.globals.eks.single_tenant
    rds = local.globals.rds.single_tenant
    sqs = local.globals.sqs.single_tenant

    # Tenant-specific tags
    tags = merge(
      local.globals.common_tags,
      local.globals.single_tenants["acme-corp"].tags,
      {
        TenantType = "single-tenant"
        TenantId   = "acme-corp"
      }
    )
  }
}

# -----------------------------------------------------------------------------
# Template for adding more single-tenant customers:
# -----------------------------------------------------------------------------
# To add a new single-tenant customer:
# 1. Add their configuration to globals.hcl under single_tenants
# 2. Copy the stack block above and update:
#    - stack name: "single-tenant-{customer-id}"
#    - path: "single-tenant/{customer-id}"
#    - All references to use the new customer key
#
# Example:
# stack "single-tenant-megacorp" {
#   source = "../_stacks/environment"
#   path   = "single-tenant/megacorp"
#   values = {
#     project_name = "megacorp"
#     environment  = local.globals.single_tenants["megacorp"].environment
#     aws_region   = local.globals.single_tenants["megacorp"].region
#     # ... rest of configuration
#   }
# }
