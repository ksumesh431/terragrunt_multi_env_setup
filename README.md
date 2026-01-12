# Multi-Tenant GDPR-Compliant Infrastructure

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

# Using environment variable (recommended for CI/CD)
export TG_PROVIDER_CACHE=1
terragrunt run --all plan
```

**Benefits:**
- Downloads each provider version only once (saves ~100MB per unit per provider)
- Shared across all units during `run --all` operations
- Persists in `~/.terragrunt-cache/terragrunt/providers/`

### Parallelism Control

Control how many units run in parallel:

```bash
# Increase parallelism (default: 10)
terragrunt run --all --parallelism 20 plan

# Environment variable
export TG_PARALLELISM=20
```

### Recommended CI/CD Environment Variables

```bash
# .env or CI/CD pipeline variables
export TG_PROVIDER_CACHE=1              # Enable provider caching
export TG_PARALLELISM=15                # Adjust based on CI runner capacity
export TG_NON_INTERACTIVE=1             # Skip prompts in CI
export TF_INPUT=0                       # Terraform non-interactive mode
```

### Complete Optimized Workflow

```bash
cd live

# Set environment variables
export TG_PROVIDER_CACHE=1
export TG_PARALLELISM=15

# Generate, plan, and apply with caching
terragrunt stack generate
terragrunt run --all plan
terragrunt run --all apply
```

---

## Configuration Guide

This project uses three key configuration files that work together.

### Overview: The Three Key Files

| File | Purpose | When to Edit |
|------|---------|--------------|
| `globals.hcl` | **Single source of truth** for all values | Changing any configuration (versions, sizes, CIDRs, etc.) |
| `live/terragrunt.stack.hcl` | **Deployment inventory** - defines WHAT to deploy | Adding/removing regions or tenants |
| `_stacks/environment/terragrunt.stack.hcl` | **Environment template** - defines HOW to deploy | Changing which components make up an environment |

### File 1: `globals.hcl` — Single Source of Truth

**Location:** Repository root

**Purpose:** Contains ALL configurable values for the entire infrastructure. No hardcoded values should exist in any other file.

**Structure:**
```hcl
locals {
  # Project identity
  project_name = "sei-platform"
  
  # Regional configurations
  regions = {
    us = { aws_region = "us-east-1", environment = "production", ... }
    eu = { aws_region = "eu-west-1", environment = "production", ... }
  }
  
  # Component configurations (per region/tenant type)
  vpc = { us = {...}, eu = {...}, single_tenant = {...} }
  eks = { us = {...}, eu = {...}, single_tenant = {...} }
  rds = { us = {...}, eu = {...}, single_tenant = {...} }
  sqs = { us = {...}, eu = {...}, single_tenant = {...} }
  
  # Single-tenant customer definitions
  single_tenants = {
    "acme-corp" = { region = "us-east-1", vpc_cidr = "10.100.0.0/16", ... }
  }
}
```

**When to edit:**
- ✅ Changing EKS version, instance types, scaling settings
- ✅ Modifying VPC CIDRs, subnet configurations
- ✅ Updating RDS settings (storage, backups, etc.)
- ✅ Adding new single-tenant customer configurations
- ✅ Changing any tags or naming conventions

---

### File 2: `live/terragrunt.stack.hcl` — Deployment Inventory

**Location:** `live/` directory

**Purpose:** The **entry point** for all deployments. Defines WHAT environments exist and passes configuration from `globals.hcl` to each one.

**Structure:**
```hcl
# Load globals
locals {
  globals = read_terragrunt_config(find_in_parent_folders("globals.hcl")).locals
}

# Multi-tenant regions
stack "us" {
  source = "../_stacks/environment"
  path   = "us"
  values = {
    vpc = local.globals.vpc.us
    eks = local.globals.eks.us
    # ... passes values from globals to the environment stack
  }
}

stack "eu" { ... }

# Single-tenant deployments
stack "single-tenant-acme-corp" {
  source = "../_stacks/environment"
  path   = "single-tenant/acme-corp"
  values = { ... }
}
```

**When to edit:**
- ✅ Adding a new region (e.g., `stack "ap" { ... }`)
- ✅ Adding a new single-tenant customer
- ✅ Removing/disabling a deployment
- ❌ Changing component settings (do that in `globals.hcl`)

---

### File 3: `_stacks/environment/terragrunt.stack.hcl` — Environment Template

**Location:** `_stacks/environment/` directory

**Purpose:** A **reusable template** that defines what components make up a complete environment. Acts as the "HOW" to deploy.

**Structure:**
```hcl
# VPC - Networking foundation
unit "vpc" {
  source = "${local.units_path}/vpc"
  path   = "vpc"
  values = { ... }  # Receives values from live/terragrunt.stack.hcl
}

# EKS - Kubernetes cluster (depends on VPC)
unit "eks" {
  source = "${local.units_path}/eks"
  path   = "eks"
  values = { ... }
}

# RDS - Database (depends on VPC)
unit "rds" { ... }

# SQS - Message queues
unit "sqs-orders" { ... }
unit "sqs-notifications" { ... }
unit "sqs-events" { ... }
```

**When to edit:**
- ✅ Adding a new component to all environments (e.g., ElastiCache)
- ✅ Removing a component from all environments
- ✅ Changing how values flow from globals to units
- ❌ Changing component configurations (do that in `globals.hcl`)

---

### How They Work Together

```text
+---------------------------------------------------------------------+
|                         globals.hcl                                 |
|               (All values: versions, sizes, CIDRs)                  |
+--------------------------------+------------------------------------+
                                 |
                                 v
+---------------------------------------------------------------------+
|                   live/terragrunt.stack.hcl                         |
|            (Reads globals, defines US/EU/single-tenant)             |
|                                                                     |
|   stack "us" -----+                                                 |
|   stack "eu" -----+--> Each uses _stacks/environment                |
|   stack "acme" ---+                                                 |
+--------------------------------+------------------------------------+
                                 |
                                 v
+---------------------------------------------------------------------+
|            _stacks/environment/terragrunt.stack.hcl                 |
|      (Defines VPC + EKS + RDS + SQS as a reusable pattern)          |
+--------------------------------+------------------------------------+
                                 |
                                 v
+---------------------------------------------------------------------+
|                          _units/                                    |
|           (Individual Terraform modules: vpc, eks, rds, sqs)        |
+---------------------------------------------------------------------+
```



---

### Adding a New Single-Tenant Customer

1. **Add customer configuration to `globals.hcl`:**

```hcl
single_tenants = {
  "acme-corp" = { ... }  # Existing
  
  # Add new customer
  "newcorp" = {
    display_name = "NewCorp Inc"
    region       = "us-west-2"
    environment  = "dedicated"
    vpc_cidr     = "10.102.0.0/16"  # Must not conflict!
    tags = {
      Customer     = "NewCorp Inc"
      ContractTier = "Enterprise"
    }
  }
}
```

2. **Add stack to `live/terragrunt.stack.hcl`:**

```hcl
stack "single-tenant-newcorp" {
  source = "../_stacks/environment"
  path   = "single-tenant/newcorp"
  values = {
    project_name = "newcorp"
    environment  = local.globals.single_tenants["newcorp"].environment
    aws_region   = local.globals.single_tenants["newcorp"].region
    # ... rest of configuration (copy from acme-corp example)
  }
}
```

3. **Deploy:**

```bash
cd live
terragrunt stack generate
cd .terragrunt-stack/single-tenant/newcorp/.terragrunt-stack
terragrunt run --all apply
```

---

## GDPR Compliance

The EU region is designed for GDPR compliance:

| Requirement | Implementation |
|-------------|----------------|
| **Data Residency** | Separate VPC, EKS, RDS in `eu-west-1` |
| **No Cross-Region Flow** | Each region has isolated resources, no replication configured |
| **Encryption at Rest** | RDS: `storage_encrypted = true`; SQS: SSE enabled |
| **Encryption in Transit** | EKS with HTTPS ingress, RDS with TLS |
| **Compliance Tags** | All resources tagged with `Compliance = GDPR`, `DataResidency = EU` |


---

### Messaging Abstraction Pattern

SQS is AWS-proprietary. For migration, use an application-level abstraction.


---

## AWS Modules Used

| Component | Module | Version |
|-----------|--------|---------|
| VPC | [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) | 5.5.1 |
| RDS | [terraform-aws-modules/rds/aws](https://registry.terraform.io/modules/terraform-aws-modules/rds/aws) | 6.4.0 |
| SQS | [terraform-aws-modules/sqs/aws](https://registry.terraform.io/modules/terraform-aws-modules/sqs/aws) | 4.1.1 |

---



> [!NOTE]
> The data flow is: `globals.hcl` → `live/terragrunt.stack.hcl` → `_stacks/environment/terragrunt.stack.hcl` → `_units/*/terragrunt.hcl`

---

## CI/CD Pipeline Setup

### GitHub Actions Example

Create `.github/workflows/terragrunt.yml`:

```yaml
name: Terragrunt CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  TF_VERSION: "1.5.7"
  TG_VERSION: "0.97.2"
  AWS_REGION: "us-east-1"

jobs:
  # ============================================
  # VALIDATE
  # ============================================
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Setup Terragrunt
        run: |
          curl -Lo terragrunt https://github.com/gruntwork-io/terragrunt/releases/download/v${{ env.TG_VERSION }}/terragrunt_linux_amd64
          chmod +x terragrunt && sudo mv terragrunt /usr/local/bin/

      - name: Terragrunt Format Check
        run: terragrunt hclfmt --check --terragrunt-working-dir live

      - name: Generate Stacks
        run: |
          cd live
          terragrunt stack generate

      - name: Validate All Units
        run: |
          cd live
          terragrunt run --all validate

  # ============================================
  # PLAN (runs on PRs)
  # ============================================
  plan:
    needs: validate
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform & Terragrunt
        # ... (same as validate)

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terragrunt Plan (US)
        env:
          TG_PROVIDER_CACHE: 1
        run: |
          cd live
          terragrunt stack generate
          cd .terragrunt-stack/us
          terragrunt run --all plan --out=tfplan

      # Repeat for EU and single-tenant if needed

  # ============================================
  # APPLY (runs on main branch push)
  # ============================================
  apply:
    needs: validate
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production  # Requires manual approval
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform & Terragrunt
        # ... (same as validate)

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}  # Use OIDC
          aws-region: ${{ env.AWS_REGION }}

      - name: Terragrunt Apply (US)
        run: |
          cd live
          terragrunt stack generate
          cd .terragrunt-stack/us
          terragrunt run --all apply --auto-approve

      # Deploy other regions sequentially or in parallel jobs
```