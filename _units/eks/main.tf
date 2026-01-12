# =============================================================================
# LOCAL EKS MODULE - Main Cluster Resources
# =============================================================================
# Core EKS cluster, KMS encryption, and OIDC provider
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

# -----------------------------------------------------------------------------
# DATA SOURCES
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.id

  # Cluster tags
  cluster_tags = merge(
    var.tags,
    var.cluster_tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# -----------------------------------------------------------------------------
# KMS KEY FOR SECRETS ENCRYPTION
# -----------------------------------------------------------------------------

resource "aws_kms_key" "cluster" {
  count = var.cluster_encryption_config && var.kms_key_arn == null ? 1 : 0

  description             = "KMS key for EKS cluster ${var.cluster_name} secrets encryption"
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = true

  policy = var.kms_key_enable_default_policy ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${local.partition}:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS Service"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  }) : null

  tags = merge(local.cluster_tags, {
    Name = "${var.cluster_name}-eks-secrets"
  })
}

resource "aws_kms_alias" "cluster" {
  count = var.cluster_encryption_config && var.kms_key_arn == null ? 1 : 0

  name          = "alias/eks/${var.cluster_name}"
  target_key_id = aws_kms_key.cluster[0].key_id
}

locals {
  kms_key_arn = var.cluster_encryption_config ? (
    var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.cluster[0].arn
  ) : null
}

# -----------------------------------------------------------------------------
# EKS CLUSTER IAM ROLE
# -----------------------------------------------------------------------------

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.cluster_tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_vpc_resource_controller" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# KMS policy for cluster role (if encryption enabled)
resource "aws_iam_role_policy" "cluster_encryption" {
  count = var.cluster_encryption_config ? 1 : 0

  name = "${var.cluster_name}-cluster-encryption"
  role = aws_iam_role.cluster.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ListGrants",
          "kms:DescribeKey"
        ]
        Resource = local.kms_key_arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CLUSTER SECURITY GROUP
# -----------------------------------------------------------------------------

resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  description = "EKS cluster security group"
  vpc_id      = var.vpc_id

  tags = merge(local.cluster_tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Default egress rule
resource "aws_security_group_rule" "cluster_egress" {
  security_group_id = aws_security_group.cluster.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all egress"
}

# Additional cluster security group rules
resource "aws_security_group_rule" "cluster_additional" {
  for_each = var.cluster_security_group_additional_rules

  security_group_id        = aws_security_group.cluster.id
  type                     = each.value.type
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  description              = each.value.description
  cidr_blocks              = each.value.cidr_blocks
  ipv6_cidr_blocks         = each.value.ipv6_cidr_blocks
  source_security_group_id = each.value.source_security_group_id
  self                     = each.value.self
}

# -----------------------------------------------------------------------------
# EKS CLUSTER
# -----------------------------------------------------------------------------

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = var.cluster_endpoint_public_access
    endpoint_private_access = var.cluster_endpoint_private_access
    public_access_cidrs     = var.cluster_endpoint_public_access ? var.cluster_endpoint_public_access_cidrs : null
    security_group_ids      = [aws_security_group.cluster.id]
  }

  # Encryption configuration
  dynamic "encryption_config" {
    for_each = var.cluster_encryption_config ? [1] : []
    content {
      provider {
        key_arn = local.kms_key_arn
      }
      resources = ["secrets"]
    }
  }

  # Kubernetes network configuration
  kubernetes_network_config {
    ip_family         = var.cluster_ip_family
    service_ipv4_cidr = var.cluster_service_ipv4_cidr
  }

  # Control plane logging
  enabled_cluster_log_types = var.cluster_enabled_log_types

  # Access configuration
  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  tags = local.cluster_tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_resource_controller,
    aws_iam_role_policy.cluster_encryption,
    aws_cloudwatch_log_group.cluster, # Create log group before cluster
  ]
}

# CloudWatch log group for cluster logs
resource "aws_cloudwatch_log_group" "cluster" {
  count = length(var.cluster_enabled_log_types) > 0 ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_in_days

  tags = local.cluster_tags

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# OIDC PROVIDER FOR IRSA
# -----------------------------------------------------------------------------

data "tls_certificate" "cluster" {
  count = var.enable_irsa ? 1 : 0

  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.enable_irsa ? 1 : 0

  client_id_list  = var.openid_connect_audiences
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(local.cluster_tags, {
    Name = "${var.cluster_name}-oidc-provider"
  })
}

# -----------------------------------------------------------------------------
# ACCESS ENTRIES
# -----------------------------------------------------------------------------

resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = each.value.principal_arn
  kubernetes_groups = each.value.kubernetes_groups
  type              = each.value.type

  tags = local.cluster_tags
}

resource "aws_eks_access_policy_association" "this" {
  for_each = merge([
    for entry_key, entry in var.access_entries : {
      for policy_key, policy in entry.policy_associations :
      "${entry_key}-${policy_key}" => {
        principal_arn = entry.principal_arn
        policy_arn    = policy.policy_arn
        access_scope  = policy.access_scope
      }
    }
  ]...)

  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = each.value.policy_arn
  principal_arn = each.value.principal_arn

  access_scope {
    type       = each.value.access_scope.type
    namespaces = each.value.access_scope.namespaces
  }

  depends_on = [aws_eks_access_entry.this]
}
