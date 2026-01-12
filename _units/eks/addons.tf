# =============================================================================
# LOCAL EKS MODULE - Cluster Addons
# =============================================================================
# EKS addons (CoreDNS, kube-proxy, vpc-cni, EBS CSI, Pod Identity Agent)
# =============================================================================

# -----------------------------------------------------------------------------
# ADDON IAM ROLES (for addons that need AWS permissions)
# -----------------------------------------------------------------------------

# VPC CNI IRSA Role
resource "aws_iam_role" "vpc_cni" {
  count = var.enable_irsa && contains(keys(var.cluster_addons), "vpc-cni") ? 1 : 0

  name = "${var.cluster_name}-vpc-cni-irsa"

  assume_role_policy = jsonencode({
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
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-node"
          }
        }
      }
    ]
  })

  tags = local.cluster_tags
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  count = var.enable_irsa && contains(keys(var.cluster_addons), "vpc-cni") ? 1 : 0

  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni[0].name
}

# EBS CSI Driver IRSA Role
resource "aws_iam_role" "ebs_csi" {
  count = var.enable_irsa && contains(keys(var.cluster_addons), "aws-ebs-csi-driver") ? 1 : 0

  name = "${var.cluster_name}-ebs-csi-irsa"

  assume_role_policy = jsonencode({
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
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = local.cluster_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = var.enable_irsa && contains(keys(var.cluster_addons), "aws-ebs-csi-driver") ? 1 : 0

  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi[0].name
}

# KMS permissions for EBS CSI (if encryption enabled)
resource "aws_iam_role_policy" "ebs_csi_kms" {
  count = var.enable_irsa && contains(keys(var.cluster_addons), "aws-ebs-csi-driver") && var.cluster_encryption_config ? 1 : 0

  name = "${var.cluster_name}-ebs-csi-kms"
  role = aws_iam_role.ebs_csi[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = local.kms_key_arn
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = local.kms_key_arn
      }
    ]
  })
}

# KMS Grant for EBS CSI Driver
# This is required because the KMS key policy alone isn't sufficient.
# The grant allows the IRSA role to use the key for EBS volume encryption.
resource "aws_kms_grant" "ebs_csi" {
  count = var.enable_irsa && contains(keys(var.cluster_addons), "aws-ebs-csi-driver") && var.cluster_encryption_config && var.kms_key_arn == null ? 1 : 0

  name              = "${var.cluster_name}-ebs-csi-grant"
  key_id            = aws_kms_key.cluster[0].key_id
  grantee_principal = aws_iam_role.ebs_csi[0].arn
  operations = [
    "Encrypt",
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "DescribeKey",
    "CreateGrant"
  ]
}

# -----------------------------------------------------------------------------
# EKS ADDONS
# -----------------------------------------------------------------------------

locals {
  # Map addon names to their IRSA roles
  addon_service_account_roles = {
    "vpc-cni"            = var.enable_irsa && contains(keys(var.cluster_addons), "vpc-cni") ? aws_iam_role.vpc_cni[0].arn : null
    "aws-ebs-csi-driver" = var.enable_irsa && contains(keys(var.cluster_addons), "aws-ebs-csi-driver") ? aws_iam_role.ebs_csi[0].arn : null
  }
}

# Data source to get the latest addon versions
data "aws_eks_addon_version" "this" {
  for_each = var.cluster_addons

  addon_name         = each.key
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = each.value.addon_version == null ? true : false
}

resource "aws_eks_addon" "this" {
  for_each = var.cluster_addons

  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.key

  # Use specified version or latest
  addon_version = coalesce(
    each.value.addon_version,
    data.aws_eks_addon_version.this[each.key].version
  )

  # Conflict resolution
  resolve_conflicts_on_create = each.value.resolve_conflicts_on_create
  resolve_conflicts_on_update = each.value.resolve_conflicts_on_update

  # Service account role (for addons that need AWS permissions)
  # Only set if addon has a role configured, otherwise leave as null
  service_account_role_arn = (
    each.value.service_account_role_arn != null
    ? each.value.service_account_role_arn
    : lookup(local.addon_service_account_roles, each.key, null)
  )

  # Custom configuration values
  configuration_values = each.value.configuration_values

  # Preserve addon on delete (to prevent workload disruption)
  preserve = each.value.preserve

  tags = merge(local.cluster_tags, {
    Name = "${var.cluster_name}-addon-${each.key}"
  })

  depends_on = [
    aws_eks_node_group.this,
    aws_iam_role_policy_attachment.vpc_cni,
    aws_iam_role_policy_attachment.ebs_csi,
    aws_iam_openid_connect_provider.cluster, # Ensure OIDC exists before IRSA roles
    aws_kms_grant.ebs_csi,                   # Ensure KMS grant exists before addon
  ]
}
