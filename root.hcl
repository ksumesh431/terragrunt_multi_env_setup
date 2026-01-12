# =============================================================================
# ROOT.HCL - COMMON TERRAGRUNT CONFIGURATION
# =============================================================================
# This file is included by all units and provides common configuration.
# =============================================================================

locals {
  # Load the single source of truth
  globals = read_terragrunt_config(find_in_parent_folders("globals.hcl")).locals
}

# -----------------------------------------------------------------------------
# REMOTE STATE CONFIGURATION
# -----------------------------------------------------------------------------
# S3 backend with NATIVE S3 LOCKING (Terraform 1.10+, no DynamoDB needed)
# 
# IMPORTANT: Before enabling, create the S3 bucket with versioning:
#   aws s3 mb s3://sei-platform-terraform-state --region us-east-1
#   aws s3api put-bucket-versioning --bucket sei-platform-terraform-state \
#     --versioning-configuration Status=Enabled
#
# Also enable Object lock feature in s3 for state locking
# 
# Uncomment below to enable remote state:

remote_state {
  backend = "s3"
  
  config = {
    bucket       = "${local.globals.project_name}-terraform-state-unique-name-12345"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# -----------------------------------------------------------------------------
# PROVIDER CONFIGURATION
# -----------------------------------------------------------------------------
# Generate AWS provider configuration
# NOTE: required_providers is NOT included here because AWS modules 
#       (vpc, eks, rds, sqs) already define their own versions.tf
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  
  contents = <<-EOF
    provider "aws" {
      region = var.aws_region

      default_tags {
        tags = var.default_tags
      }
    }

    variable "aws_region" {
      description = "AWS region for resource deployment"
      type        = string
    }

    variable "default_tags" {
      description = "Default tags applied to all resources"
      type        = map(string)
      default     = {}
    }
  EOF
}

# -----------------------------------------------------------------------------
# COMMON INPUTS
# -----------------------------------------------------------------------------
# These inputs are available to all units
inputs = {
  default_tags = local.globals.common_tags
}

