# Multi-Tenant Infrastructure

A multi-tenant infrastructure platform built with **Terragrunt Stacks (v0.97+)**.

## Features

- 🏗️ **Multi-tenant architecture** with regional isolation
- 🇪🇺 **GDPR/CCPA compliant** EU deployment with data residency guarantees  
- 🔒 **Single-tenant support** for enterprise customers (fully isolated VPC/EKS/RDS)
- 📦 **Container-first** using EKS for workload portability
- 🗃️ **Standard PostgreSQL** for database portability
- 🔧 **Single source of truth** (`globals.hcl`) for all configurations

---

## Architecture Overview

```text
+-------------------------------------------------------------------------+
|                         GLOBAL CONFIGURATION                            |
|                           (globals.hcl)                                 |
+------------------------------------+------------------------------------+
                                     |
         +--------------------------++--------------------------+
         |                          |                           |
         v                          v                           v
+----------------+        +----------------+        +-----------------------+
|   US REGION    |        |   EU REGION    |        |    SINGLE-TENANT      |
|   (us-east-1)  |        |   (eu-west-1)  |        |    (per customer)     |
|                |        |                |        |                       |
|  Multi-tenant  |        |  GDPR Isolated |        |  Fully Isolated Stack |
|  Shared Infra  |        |  No data exits |        |  - Own VPC            |
+-------+--------+        +-------+--------+        |  - Own EKS            |
        |                         |                 |  - Own RDS            |
        v                         v                 +-----------------------+
+-------------------------------------+
|  Per-Region Resources:              |
|  - VPC (3 AZs, public/private/DB)   |
|  - EKS Cluster (managed nodes)      |
|  - RDS PostgreSQL (encrypted)       |
|  - SQS Queues (SSE enabled)         |
+-------------------------------------+
```

---

## Directory Structure

```
.
├── globals.hcl                    # 🎯 SINGLE SOURCE OF TRUTH
├── root.hcl                       # Common Terragrunt config (state, providers)
├── .gitignore                     # Excludes .terragrunt-stack/, etc.
│
├── _units/                        # Reusable infrastructure units
│   ├── vpc/terragrunt.hcl         # VPC (uses remote AWS module)
│   ├── eks/                       # EKS (local Terraform module)
│   │   ├── terragrunt.hcl         # Terragrunt wrapper
│   │   ├── main.tf                # Cluster, KMS, OIDC, IAM
│   │   ├── node_groups.tf         # Managed node groups
│   │   ├── addons.tf              # EKS addons with IRSA
│   │   ├── variables.tf           # All input variables
│   │   └── outputs.tf             # Module outputs
│   ├── rds/terragrunt.hcl         # RDS PostgreSQL (uses remote AWS module)
│   └── sqs/terragrunt.hcl         # SQS (uses remote AWS module)
│
├── _stacks/                       # Reusable stack patterns
│   └── environment/
│       └── terragrunt.stack.hcl   # Full environment (VPC+EKS+RDS+SQS)
│
└── live/                          # Deployment entry point
    └── terragrunt.stack.hcl       # Root orchestrator (US, EU, single-tenant)
```

---

## Quick Start

### Prerequisites

- [Terragrunt v0.97+](https://terragrunt.gruntwork.io/docs/getting-started/install/)
- [Terraform v1.5+](https://developer.hashicorp.com/terraform/install)
- AWS CLI configured with appropriate credentials

### Terragrunt Stack Commands

```bash
# Navigate to the live directory
cd live

# 1. Generate all stacks (creates .terragrunt-stack/ directory)
terragrunt stack generate

# 2. Preview what will be deployed
terragrunt run --all plan

# 3. Deploy all infrastructure
terragrunt run --all apply

# 4. Deploy specific region only
cd .terragrunt-stack/us
terragrunt run --all apply

# 5. Destroy specific region
cd .terragrunt-stack/eu
terragrunt run --all destroy
```

### Deploy a Single-Tenant Customer

```bash
cd live/.terragrunt-stack/single-tenant/acme-corp/.terragrunt-stack
terragrunt run --all apply
```

### Debug Individual Units

Navigate directly into a unit directory to plan/apply/debug a single component:

```bash
# Example: Debug only the EKS unit in EU region
cd live/.terragrunt-stack/eu/.terragrunt-stack/eks
terragrunt run plan      # Plan only EKS
terragrunt run apply     # Apply only EKS

# Example: Debug RDS in single-tenant
cd live/.terragrunt-stack/single-tenant/acme-corp/.terragrunt-stack/rds
terragrunt run plan
```

**Directory structure:**
```
live/.terragrunt-stack/
├── us/.terragrunt-stack/
│   ├── vpc/       ← terragrunt run plan
│   ├── eks/       ← terragrunt run plan
│   ├── rds/       ← terragrunt run plan
│   └── sqs/{orders,notifications,events}/
├── eu/.terragrunt-stack/
│   └── (same structure)
└── single-tenant/acme-corp/.terragrunt-stack/
    └── (same structure)
```

---

## Performance Optimizations

### Provider Cache Server

Enable the **Provider Cache Server** to dramatically speed up `run --all` commands by downloading each provider only once:

```bash
# Using flag
terragrunt run --all --provider-cache plan

### Recommended CI/CD Environment Variables

```bash
# .env or CI/CD pipeline variables
export TG_PROVIDER_CACHE=1              # Enable provider caching
export TG_PARALLELISM=15                # Adjust based on CI runner capacity
export TG_NON_INTERACTIVE=1             # Skip prompts in CI
export TF_INPUT=0                       # Terraform non-interactive mode
```
