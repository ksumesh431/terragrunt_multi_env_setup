# =============================================================================
# SQS UNIT - AWS SQS Module Wrapper
# =============================================================================
# Uses the official AWS SQS Terraform module
# Source: https://registry.terraform.io/modules/terraform-aws-modules/sqs/aws
# =============================================================================

terraform {
  source = "tfr:///terraform-aws-modules/sqs/aws?version=4.1.1"
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# -----------------------------------------------------------------------------
# INPUTS
# -----------------------------------------------------------------------------
inputs = {
  # Provider configuration
  aws_region = values.aws_region

  name = "${values.project_name}-${values.environment}-${values.queue_name}"

  # Queue configuration
  visibility_timeout_seconds  = values.visibility_timeout_seconds
  message_retention_seconds   = values.message_retention_seconds
  receive_wait_time_seconds   = values.receive_wait_time_seconds

  # Enable server-side encryption (SSE)
  sqs_managed_sse_enabled = values.sqs_managed_sse_enabled

  # Dead letter queue (optional - can be configured per queue)
  # create_dlq = true
  # dlq_message_retention_seconds = 1209600  # 14 days
  # redrive_policy = {
  #   maxReceiveCount = 3
  # }

  # Tags
  tags = merge(
    values.tags,
    {
      Component = "messaging"
      QueueName = values.queue_name
    }
  )
}
