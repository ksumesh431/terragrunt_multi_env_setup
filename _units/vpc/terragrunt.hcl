# =============================================================================
# VPC UNIT - AWS VPC Module Wrapper
# =============================================================================
# Uses the official AWS VPC Terraform module
# Source: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws
# =============================================================================

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.5.1"
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# -----------------------------------------------------------------------------
# INPUTS
# -----------------------------------------------------------------------------
# Values are passed from the stack via terragrunt.values.hcl
inputs = {
  # Provider configuration
  aws_region = values.aws_region

  name = "${values.project_name}-${values.environment}-vpc"
  cidr = values.cidr

  azs              = values.azs
  private_subnets  = values.private_subnets
  public_subnets   = values.public_subnets
  database_subnets = values.database_subnets

  # NAT Gateway configuration
  enable_nat_gateway     = values.enable_nat_gateway
  single_nat_gateway     = values.single_nat_gateway
  one_nat_gateway_per_az = values.one_nat_gateway_per_az

  # DNS settings (required for EKS and RDS)
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Database subnet group
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # EKS subnet tags for load balancer discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                              = 1
    "kubernetes.io/cluster/${values.project_name}-${values.environment}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                     = 1
    "kubernetes.io/cluster/${values.project_name}-${values.environment}" = "shared"
  }

  # Tags
  tags = merge(
    values.tags,
    {
      Component = "networking"
    }
  )
}
