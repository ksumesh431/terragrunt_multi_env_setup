# =============================================================================
# LOCAL EKS MODULE - Outputs
# =============================================================================
# All module outputs for use by dependent resources
# =============================================================================

# -----------------------------------------------------------------------------
# CLUSTER OUTPUTS
# -----------------------------------------------------------------------------

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_version" {
  description = "The Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_status" {
  description = "The status of the EKS cluster"
  value       = aws_eks_cluster.this.status
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_platform_version" {
  description = "The platform version of the EKS cluster"
  value       = aws_eks_cluster.this.platform_version
}

# -----------------------------------------------------------------------------
# SECURITY GROUP OUTPUTS
# -----------------------------------------------------------------------------

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "cluster_security_group_arn" {
  description = "Security group ARN attached to the EKS cluster"
  value       = aws_security_group.cluster.arn
}

output "cluster_primary_security_group_id" {
  description = "The cluster primary security group ID created by EKS"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = length(var.node_groups) > 0 ? aws_security_group.node[0].id : null
}

output "node_security_group_arn" {
  description = "Security group ARN attached to the EKS nodes"
  value       = length(var.node_groups) > 0 ? aws_security_group.node[0].arn : null
}

# -----------------------------------------------------------------------------
# IAM OUTPUTS
# -----------------------------------------------------------------------------

output "cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster"
  value       = aws_iam_role.cluster.name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_name" {
  description = "IAM role name of the EKS node group"
  value       = length(var.node_groups) > 0 ? aws_iam_role.node[0].name : null
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS node group"
  value       = length(var.node_groups) > 0 ? aws_iam_role.node[0].arn : null
}

# -----------------------------------------------------------------------------
# OIDC / IRSA OUTPUTS
# -----------------------------------------------------------------------------

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.cluster[0].arn : null
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.cluster[0].url : null
}

output "oidc_issuer" {
  description = "The OIDC issuer URL (without https://)"
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# -----------------------------------------------------------------------------
# KMS OUTPUTS
# -----------------------------------------------------------------------------

output "kms_key_arn" {
  description = "ARN of the KMS key used for secrets encryption"
  value       = local.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for secrets encryption"
  value       = var.cluster_encryption_config && var.kms_key_arn == null ? aws_kms_key.cluster[0].key_id : null
}

# -----------------------------------------------------------------------------
# NODE GROUP OUTPUTS
# -----------------------------------------------------------------------------

output "node_groups" {
  description = "Map of node groups created"
  value = {
    for k, v in aws_eks_node_group.this : k => {
      arn            = v.arn
      id             = v.id
      status         = v.status
      capacity_type  = v.capacity_type
      instance_types = v.instance_types
      scaling_config = v.scaling_config
    }
  }
}

output "node_group_arns" {
  description = "ARNs of the EKS node groups"
  value       = { for k, v in aws_eks_node_group.this : k => v.arn }
}

output "node_group_autoscaling_group_names" {
  description = "Autoscaling group names of the node groups"
  value = {
    for k, v in aws_eks_node_group.this : k =>
    length(v.resources) > 0 ? [for r in v.resources : r.autoscaling_groups[*].name][0] : []
  }
}

# -----------------------------------------------------------------------------
# ADDON OUTPUTS
# -----------------------------------------------------------------------------

output "cluster_addons" {
  description = "Map of cluster addons"
  value = {
    for k, v in aws_eks_addon.this : k => {
      arn     = v.arn
      version = v.addon_version
    }
  }
}

# -----------------------------------------------------------------------------
# CLOUDWATCH OUTPUTS
# -----------------------------------------------------------------------------

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for cluster logs"
  value       = length(var.cluster_enabled_log_types) > 0 ? aws_cloudwatch_log_group.cluster[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for cluster logs"
  value       = length(var.cluster_enabled_log_types) > 0 ? aws_cloudwatch_log_group.cluster[0].arn : null
}

# -----------------------------------------------------------------------------
# NETWORK OUTPUTS
# -----------------------------------------------------------------------------

output "cluster_vpc_config" {
  description = "VPC configuration of the cluster"
  value = {
    vpc_id                  = var.vpc_id
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = var.cluster_endpoint_public_access
    endpoint_private_access = var.cluster_endpoint_private_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }
}

# -----------------------------------------------------------------------------
# HELPER OUTPUTS (for IRSA role creation)
# -----------------------------------------------------------------------------

output "irsa_assume_role_policy" {
  description = "Template for IRSA assume role policy"
  value = var.enable_irsa ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  }) : null
}
