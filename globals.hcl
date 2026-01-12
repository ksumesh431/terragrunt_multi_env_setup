# =============================================================================
# GLOBALS.HCL - SINGLE SOURCE OF TRUTH
# =============================================================================
# This file contains ALL configuration values for ALL environments.
# Modify values here to customize deployments across regions and tenants.
# =============================================================================

locals {
  # ===========================================================================
  # PROJECT METADATA
  # ===========================================================================
  project_name = "sei-platform"
  
  # ===========================================================================
  # REGIONAL CONFIGURATION
  # ===========================================================================
  # Define all deployment regions and their compliance requirements
  regions = {
    us = {
      aws_region     = "us-east-1"
      environment    = "production"
      is_gdpr_region = false
      # Compliance tags added to all resources in this region
      compliance_tags = {}
    }
    eu = {
      aws_region     = "eu-west-1"
      environment    = "production"
      is_gdpr_region = true
      # These tags are added to all resources for compliance tracking
      compliance_tags = {
        Compliance       = "GDPR"
        DataResidency    = "EU"
        DataClassification = "PII"
      }
    }
  }

  # ===========================================================================
  # VPC CONFIGURATION
  # ===========================================================================
  # Network configuration per region/tenant type
  vpc = {
    # US Region - Multi-tenant shared infrastructure
    us = {
      cidr             = "10.0.0.0/16"
      azs              = ["us-east-1a", "us-east-1b", "us-east-1c"]
      private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
      public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
      database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
      
      # NAT Gateway configuration
      enable_nat_gateway     = true
      single_nat_gateway     = false  # HA: one per AZ
      one_nat_gateway_per_az = true
    }
    
    # EU Region - GDPR isolated infrastructure
    eu = {
      cidr             = "10.1.0.0/16"
      azs              = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
      private_subnets  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
      public_subnets   = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
      database_subnets = ["10.1.201.0/24", "10.1.202.0/24", "10.1.203.0/24"]
      
      enable_nat_gateway     = true
      single_nat_gateway     = false
      one_nat_gateway_per_az = true
    }
    
    # Single-tenant base configuration (customizable per tenant)
    single_tenant = {
      cidr             = "10.100.0.0/16"
      azs              = ["us-east-1a", "us-east-1b"]  # 2 AZs for cost optimization
      private_subnets  = ["10.100.1.0/24", "10.100.2.0/24"]
      public_subnets   = ["10.100.101.0/24", "10.100.102.0/24"]
      database_subnets = ["10.100.201.0/24", "10.100.202.0/24"]
      
      enable_nat_gateway     = true
      single_nat_gateway     = true  # Cost optimization for single tenant
      one_nat_gateway_per_az = false
    }
  }

  # ===========================================================================
  # EKS CONFIGURATION
  # ===========================================================================
  # Kubernetes cluster settings per region/tenant type
  # All parameters from local _units/eks module are exposed here
  eks = {
    # -------------------------------------------------------------------------
    # US Region - Multi-tenant
    # -------------------------------------------------------------------------
    us = {
      # Cluster version
      cluster_version = "1.34"

      # Endpoint access
      cluster_endpoint_public_access       = true
      cluster_endpoint_private_access      = true
      cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

      # Logging
      cluster_enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
      cluster_log_retention_in_days = 90

      # Encryption
      cluster_encryption_config       = true
      kms_key_deletion_window_in_days = 30

      # IRSA (IAM Roles for Service Accounts)
      enable_irsa = true

      # Pod Identity
      enable_pod_identity_agent = true

      # Authentication
      authentication_mode                         = "API_AND_CONFIG_MAP"
      bootstrap_cluster_creator_admin_permissions = true

      # Addons - all recommended defaults
      cluster_addons = {
        coredns = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        kube-proxy = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        vpc-cni = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        aws-ebs-csi-driver = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        eks-pod-identity-agent = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
      }

      # Node groups
      node_groups = {
        main = {
          min_size     = 1
          max_size     = 10
          desired_size = 1

          instance_types = ["t3.large"]
          capacity_type  = "ON_DEMAND"
          ami_type       = "AL2023_x86_64_STANDARD"

          disk_size      = 50
          disk_type      = "gp3"
          disk_encrypted = true

          labels = {
            Environment = "production"
            NodeType    = "general"
          }
          taints = []

          # IMDSv2 enforcement
          http_endpoint               = "enabled"
          http_tokens                 = "required"
          http_put_response_hop_limit = 1

          use_custom_launch_template = true
          max_unavailable            = 1
        }
      }

      # Additional security group rules
      cluster_security_group_additional_rules = {}
      node_security_group_additional_rules    = {}
    }

    # -------------------------------------------------------------------------
    # EU Region - GDPR isolated
    # -------------------------------------------------------------------------
    eu = {
      cluster_version = "1.34"

      cluster_endpoint_public_access       = true
      cluster_endpoint_private_access      = true
      cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

      cluster_enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
      cluster_log_retention_in_days = 365  # GDPR: Extended log retention

      cluster_encryption_config       = true
      kms_key_deletion_window_in_days = 30

      enable_irsa               = true
      enable_pod_identity_agent = true

      authentication_mode                         = "API_AND_CONFIG_MAP"
      bootstrap_cluster_creator_admin_permissions = true

      cluster_addons = {
        coredns = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        kube-proxy = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        vpc-cni = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        aws-ebs-csi-driver = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        eks-pod-identity-agent = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
      }

      node_groups = {
        main = {
          min_size     = 1
          max_size     = 10
          desired_size = 1

          instance_types = ["t3.large"]
          capacity_type  = "ON_DEMAND"
          ami_type       = "AL2023_x86_64_STANDARD"

          disk_size      = 50
          disk_type      = "gp3"
          disk_encrypted = true

          labels = {
            Environment = "production"
            NodeType    = "general"
            Compliance  = "GDPR"
          }
          taints = []

          http_endpoint               = "enabled"
          http_tokens                 = "required"
          http_put_response_hop_limit = 1

          use_custom_launch_template = true
          max_unavailable            = 1
        }
      }

      cluster_security_group_additional_rules = {}
      node_security_group_additional_rules    = {}
    }

    # -------------------------------------------------------------------------
    # Single-tenant - Dedicated resources
    # -------------------------------------------------------------------------
    single_tenant = {
      cluster_version = "1.34"

      cluster_endpoint_public_access       = true
      cluster_endpoint_private_access      = true
      cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

      cluster_enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
      cluster_log_retention_in_days = 90

      cluster_encryption_config       = true
      kms_key_deletion_window_in_days = 30

      enable_irsa               = true
      enable_pod_identity_agent = true

      authentication_mode                         = "API_AND_CONFIG_MAP"
      bootstrap_cluster_creator_admin_permissions = true

      cluster_addons = {
        coredns = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        kube-proxy = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        vpc-cni = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        aws-ebs-csi-driver = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
        eks-pod-identity-agent = {
          resolve_conflicts_on_create = "OVERWRITE"
          resolve_conflicts_on_update = "OVERWRITE"
        }
      }

      node_groups = {
        dedicated = {
          min_size     = 1
          max_size     = 5
          desired_size = 1

          instance_types = ["t3.xlarge"]  # Larger for dedicated tenant
          capacity_type  = "ON_DEMAND"
          ami_type       = "AL2023_x86_64_STANDARD"

          disk_size      = 100
          disk_type      = "gp3"
          disk_encrypted = true

          labels = {
            Environment = "dedicated"
            NodeType    = "single-tenant"
          }
          taints = []

          http_endpoint               = "enabled"
          http_tokens                 = "required"
          http_put_response_hop_limit = 1

          use_custom_launch_template = true
          max_unavailable            = 1
        }
      }

      cluster_security_group_additional_rules = {}
      node_security_group_additional_rules    = {}
    }
  }

  # ===========================================================================
  # RDS POSTGRESQL CONFIGURATION
  # ===========================================================================
  # Database settings per region/tenant type
  rds = {
    # US Region
    us = {
      engine               = "postgres"
      engine_version       = "17.6"
      family               = "postgres17"
      major_engine_version = "17"
      instance_class       = "db.t3.large"
      allocated_storage    = 100
      max_allocated_storage = 500  # Autoscaling limit
      storage_type         = "gp3"
      
      # Database settings
      db_name     = "app"
      db_username = "dbadmin"
      db_port     = 5432
      
      # High availability
      multi_az = true
      
      # Backup configuration
      backup_retention_period = 7
      backup_window           = "03:00-04:00"
      maintenance_window      = "Mon:04:00-Mon:05:00"
      skip_final_snapshot     = false
      
      # Security
      storage_encrypted   = true
      deletion_protection = true
      
      # Monitoring
      performance_insights_enabled = true
      monitoring_interval          = 60
    }
    
    # EU Region - GDPR compliant
    eu = {
      engine               = "postgres"
      engine_version       = "17.6"
      family               = "postgres17"
      major_engine_version = "17"
      instance_class       = "db.t3.large"
      allocated_storage    = 100
      max_allocated_storage = 500
      storage_type         = "gp3"
      
      # Database settings
      db_name     = "app"
      db_username = "dbadmin"
      db_port     = 5432
      
      multi_az = true
      
      # GDPR: Extended backup retention
      backup_retention_period = 30
      backup_window           = "03:00-04:00"
      maintenance_window      = "Mon:04:00-Mon:05:00"
      skip_final_snapshot     = false
      
      # GDPR: Must be encrypted
      storage_encrypted   = true
      deletion_protection = true
      
      # Monitoring
      performance_insights_enabled = true
      monitoring_interval          = 60
      
      # GDPR: Ensure backups stay in-region (no cross-region replication)
      # This is enforced by NOT configuring cross-region replicas
    }
    
    # Single-tenant - Cost optimized
    single_tenant = {
      engine               = "postgres"
      engine_version       = "17.6"
      family               = "postgres17"
      major_engine_version = "17"
      instance_class       = "db.t3.medium"  # Smaller for single tenant
      allocated_storage    = 50
      max_allocated_storage = 200
      storage_type         = "gp3"
      
      # Database settings
      db_name     = "app"
      db_username = "dbadmin"
      db_port     = 5432
      
      multi_az = false  # Cost optimization (can be enabled per tenant req)
      
      backup_retention_period = 7
      backup_window           = "03:00-04:00"
      maintenance_window      = "Mon:04:00-Mon:05:00"
      skip_final_snapshot     = false
      
      storage_encrypted   = true
      deletion_protection = true
      
      # Monitoring
      performance_insights_enabled = false  # Cost optimization
      monitoring_interval          = 0      # Disabled for cost savings
    }
  }

  # ===========================================================================
  # SQS CONFIGURATION
  # ===========================================================================
  # Message queue settings
  sqs = {
    # Queue definitions (created in all regions)
    queues = ["orders", "notifications", "events"]
    
    # US Region settings
    us = {
      visibility_timeout_seconds  = 30
      message_retention_seconds   = 1209600  # 14 days
      receive_wait_time_seconds   = 10       # Long polling
      sqs_managed_sse_enabled     = true     # Encryption at rest
    }
    
    # EU Region settings - GDPR compliant
    eu = {
      visibility_timeout_seconds  = 30
      message_retention_seconds   = 1209600
      receive_wait_time_seconds   = 10
      sqs_managed_sse_enabled     = true
      # GDPR: No cross-region replication configured
    }
    
    # Single-tenant settings
    single_tenant = {
      visibility_timeout_seconds  = 30
      message_retention_seconds   = 1209600
      receive_wait_time_seconds   = 10
      sqs_managed_sse_enabled     = true
    }
  }

  # ===========================================================================
  # SINGLE-TENANT REGISTRY
  # ===========================================================================
  # Add new single-tenant customers here
  # Each entry creates a fully isolated infrastructure stack
  single_tenants = {
    "acme-corp" = {
      display_name = "ACME Corporation"
      region       = "us-east-1"
      environment  = "dedicated"
      
      # Override base VPC CIDR if needed (must not conflict)
      vpc_cidr = "10.100.0.0/16"
      
      # Custom tags for this tenant
      tags = {
        Customer     = "ACME Corporation"
        ContractTier = "Enterprise"
      }
    }
    
    # Example: Add another single-tenant customer
    # "megacorp" = {
    #   display_name = "MegaCorp Inc"
    #   region       = "eu-west-1"  # EU customer with GDPR needs
    #   environment  = "dedicated"
    #   vpc_cidr     = "10.101.0.0/16"
    #   tags = {
    #     Customer     = "MegaCorp Inc"
    #     ContractTier = "Enterprise"
    #     Compliance   = "GDPR"
    #   }
    # }
  }

  # ===========================================================================
  # COMMON TAGS
  # ===========================================================================
  # Applied to all resources across all environments
  common_tags = {
    Project   = local.project_name
    ManagedBy = "Terragrunt"
    IaC       = "true"
  }
}
