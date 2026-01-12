# =============================================================================
# LOCAL EKS MODULE - Variables
# =============================================================================
# All configurable parameters for the EKS cluster
# =============================================================================

# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster (control plane ENIs)"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# CLUSTER CONFIGURATION
# -----------------------------------------------------------------------------

variable "cluster_endpoint_public_access" {
  description = "Enable public access to the cluster API endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to the cluster API endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks allowed to access the public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_in_days" {
  description = "Number of days to retain cluster logs in CloudWatch"
  type        = number
  default     = 90
}

variable "cluster_ip_family" {
  description = "IP family for the cluster (ipv4 or ipv6)"
  type        = string
  default     = "ipv4"
}

variable "cluster_service_ipv4_cidr" {
  description = "CIDR block for Kubernetes service IPs"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# ENCRYPTION
# -----------------------------------------------------------------------------

variable "cluster_encryption_config" {
  description = "Enable envelope encryption for Kubernetes secrets"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of existing KMS key for secrets encryption (if null, a new key is created)"
  type        = string
  default     = null
}

variable "kms_key_deletion_window_in_days" {
  description = "Duration in days before KMS key is deleted after destruction"
  type        = number
  default     = 30
}

variable "kms_key_enable_default_policy" {
  description = "Enable default key policy that gives account full access"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# OIDC / IRSA
# -----------------------------------------------------------------------------

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA)"
  type        = bool
  default     = true
}

variable "openid_connect_audiences" {
  description = "List of OpenID Connect audiences"
  type        = list(string)
  default     = ["sts.amazonaws.com"]
}

# -----------------------------------------------------------------------------
# POD IDENTITY
# -----------------------------------------------------------------------------

variable "enable_pod_identity_agent" {
  description = "Enable EKS Pod Identity Agent addon"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# CLUSTER ADDONS
# -----------------------------------------------------------------------------

variable "cluster_addons" {
  description = "Map of EKS cluster addons to enable"
  type = map(object({
    addon_version               = optional(string)
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    service_account_role_arn    = optional(string)
    configuration_values        = optional(string)
    preserve                    = optional(bool, true)
  }))
  default = {
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
}

# -----------------------------------------------------------------------------
# NODE GROUPS
# -----------------------------------------------------------------------------

variable "node_groups" {
  description = "Map of EKS managed node group configurations"
  type = map(object({
    # Scaling
    min_size     = number
    max_size     = number
    desired_size = number

    # Instance configuration
    instance_types = list(string)
    capacity_type  = optional(string, "ON_DEMAND") # ON_DEMAND or SPOT
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")

    # Disk configuration
    disk_size      = optional(number, 50)
    disk_type      = optional(string, "gp3")
    disk_iops      = optional(number)
    disk_throughput = optional(number)
    disk_encrypted = optional(bool, true)
    disk_kms_key_id = optional(string)

    # Kubernetes configuration
    kubernetes_version = optional(string)
    labels             = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string # NO_SCHEDULE, NO_EXECUTE, PREFER_NO_SCHEDULE
    })), [])

    # Update configuration
    max_unavailable            = optional(number, 1)
    max_unavailable_percentage = optional(number)

    # Launch template
    use_custom_launch_template = optional(bool, true)

    # Instance metadata options (IMDSv2)
    http_endpoint               = optional(string, "enabled")
    http_tokens                 = optional(string, "required")
    http_put_response_hop_limit = optional(number, 1)

    # Remote access (SSH)
    remote_access_enabled      = optional(bool, false)
    remote_access_key_name     = optional(string)
    remote_access_sg_ids       = optional(list(string), [])

    # Additional settings
    force_update_version = optional(bool, false)
    subnet_ids          = optional(list(string))
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# SECURITY GROUPS
# -----------------------------------------------------------------------------

variable "cluster_security_group_additional_rules" {
  description = "Additional security group rules for the cluster"
  type = map(object({
    description              = string
    protocol                 = string
    from_port                = number
    to_port                  = number
    type                     = string
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
    source_security_group_id = optional(string)
    self                     = optional(bool)
  }))
  default = {}
}

variable "node_security_group_additional_rules" {
  description = "Additional security group rules for nodes"
  type = map(object({
    description              = string
    protocol                 = string
    from_port                = number
    to_port                  = number
    type                     = string
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
    source_security_group_id = optional(string)
    self                     = optional(bool)
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# ACCESS CONTROL
# -----------------------------------------------------------------------------

variable "authentication_mode" {
  description = "Authentication mode for the cluster (CONFIG_MAP, API, or API_AND_CONFIG_MAP)"
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Bootstrap cluster creator with admin permissions"
  type        = bool
  default     = true
}

variable "access_entries" {
  description = "Map of access entries for the cluster"
  type = map(object({
    principal_arn     = string
    kubernetes_groups = optional(list(string), [])
    type              = optional(string, "STANDARD")
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        type       = string
        namespaces = optional(list(string), [])
      })
    })), {})
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# TAGS
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "cluster_tags" {
  description = "Additional tags for the EKS cluster only"
  type        = map(string)
  default     = {}
}

variable "node_group_tags" {
  description = "Additional tags for node groups"
  type        = map(string)
  default     = {}
}
