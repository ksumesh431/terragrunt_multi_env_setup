# =============================================================================
# LOCAL EKS MODULE - Managed Node Groups
# =============================================================================
# EKS managed node groups with launch templates and IAM roles
# =============================================================================

# -----------------------------------------------------------------------------
# NODE GROUP IAM ROLE
# -----------------------------------------------------------------------------

resource "aws_iam_role" "node" {
  count = length(var.node_groups) > 0 ? 1 : 0

  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.cluster_tags, {
    Name = "${var.cluster_name}-node-role"
  })
}

# Node IAM policies
resource "aws_iam_role_policy_attachment" "node_worker" {
  count = length(var.node_groups) > 0 ? 1 : 0

  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node[0].name
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  count = length(var.node_groups) > 0 ? 1 : 0

  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node[0].name
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  count = length(var.node_groups) > 0 ? 1 : 0

  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node[0].name
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  count = length(var.node_groups) > 0 ? 1 : 0

  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node[0].name
}

# -----------------------------------------------------------------------------
# NODE SECURITY GROUP
# -----------------------------------------------------------------------------

resource "aws_security_group" "node" {
  count = length(var.node_groups) > 0 ? 1 : 0

  name_prefix = "${var.cluster_name}-node-"
  description = "EKS node security group"
  vpc_id      = var.vpc_id

  tags = merge(local.cluster_tags, {
    Name                                        = "${var.cluster_name}-node-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Node to node communication
resource "aws_security_group_rule" "node_to_node" {
  count = length(var.node_groups) > 0 ? 1 : 0

  security_group_id        = aws_security_group.node[0].id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.node[0].id
  description              = "Node to node communication"
}

# Control plane to nodes (for kubectl exec, logs, etc.)
resource "aws_security_group_rule" "cluster_to_node" {
  count = length(var.node_groups) > 0 ? 1 : 0

  security_group_id        = aws_security_group.node[0].id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  description              = "Cluster API to nodes"
}

resource "aws_security_group_rule" "cluster_to_node_kubelet" {
  count = length(var.node_groups) > 0 ? 1 : 0

  security_group_id        = aws_security_group.node[0].id
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  description              = "Cluster API to node kubelet"
}

# Nodes to control plane
resource "aws_security_group_rule" "node_to_cluster" {
  count = length(var.node_groups) > 0 ? 1 : 0

  security_group_id        = aws_security_group.cluster.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node[0].id
  description              = "Nodes to cluster API"
}

# Node egress
resource "aws_security_group_rule" "node_egress" {
  count = length(var.node_groups) > 0 ? 1 : 0

  security_group_id = aws_security_group.node[0].id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all egress"
}

# CoreDNS port
resource "aws_security_group_rule" "node_coredns_tcp" {
  count = length(var.node_groups) > 0 ? 1 : 0

  security_group_id        = aws_security_group.node[0].id
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node[0].id
  description              = "CoreDNS TCP"
}

resource "aws_security_group_rule" "node_coredns_udp" {
  count = length(var.node_groups) > 0 ? 1 : 0

  security_group_id        = aws_security_group.node[0].id
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  source_security_group_id = aws_security_group.node[0].id
  description              = "CoreDNS UDP"
}

# Additional node security group rules
resource "aws_security_group_rule" "node_additional" {
  for_each = var.node_security_group_additional_rules

  security_group_id        = aws_security_group.node[0].id
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
# LAUNCH TEMPLATES
# -----------------------------------------------------------------------------

resource "aws_launch_template" "node" {
  for_each = { for k, v in var.node_groups : k => v if v.use_custom_launch_template }

  name_prefix = "${var.cluster_name}-${each.key}-"
  description = "Launch template for ${var.cluster_name} ${each.key} node group"

  # Block device mappings
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = each.value.disk_size
      volume_type           = each.value.disk_type
      iops                  = each.value.disk_iops
      throughput            = each.value.disk_throughput
      encrypted             = each.value.disk_encrypted
      kms_key_id            = each.value.disk_kms_key_id
      delete_on_termination = true
    }
  }

  # Instance metadata options (IMDSv2)
  metadata_options {
    http_endpoint               = each.value.http_endpoint
    http_tokens                 = each.value.http_tokens
    http_put_response_hop_limit = each.value.http_put_response_hop_limit
  }

  # Monitoring
  monitoring {
    enabled = true
  }

  # Network interfaces
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.node[0].id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.cluster_tags, var.node_group_tags, {
      Name = "${var.cluster_name}-${each.key}"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.cluster_tags, {
      Name = "${var.cluster_name}-${each.key}-volume"
    })
  }

  tags = merge(local.cluster_tags, {
    Name = "${var.cluster_name}-${each.key}-lt"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# MANAGED NODE GROUPS
# -----------------------------------------------------------------------------

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node[0].arn

  # Subnets (use provided or fall back to cluster subnets)
  subnet_ids = coalesce(each.value.subnet_ids, var.subnet_ids)

  # Scaling configuration
  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  # Update configuration
  update_config {
    max_unavailable            = each.value.max_unavailable_percentage == null ? each.value.max_unavailable : null
    max_unavailable_percentage = each.value.max_unavailable_percentage
  }

  # Instance types and capacity
  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type
  ami_type       = each.value.ami_type

  # Kubernetes version (defaults to cluster version)
  version = coalesce(each.value.kubernetes_version, var.cluster_version)

  # Labels
  labels = each.value.labels

  # Taints
  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Launch template (if custom)
  dynamic "launch_template" {
    for_each = each.value.use_custom_launch_template ? [1] : []
    content {
      id      = aws_launch_template.node[each.key].id
      version = aws_launch_template.node[each.key].latest_version
    }
  }

  # Remote access (SSH)
  dynamic "remote_access" {
    for_each = each.value.remote_access_enabled ? [1] : []
    content {
      ec2_ssh_key               = each.value.remote_access_key_name
      source_security_group_ids = each.value.remote_access_sg_ids
    }
  }

  # Force update
  force_update_version = each.value.force_update_version

  tags = merge(local.cluster_tags, var.node_group_tags, {
    Name = "${var.cluster_name}-${each.key}"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_ssm,
  ]

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size,
    ]
  }
}
