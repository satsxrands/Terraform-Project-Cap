# Prerequisites

Concepts an audience should already understand (or be pointed to) before walking through this
project: a Terraform-managed EKS deployment across `dev`, `qa`, and `prd`, with GitHub Actions
driving plan/apply/destroy via AWS OIDC.

## AWS

**Identity & Access (IAM)**
- IAM roles, policies, and policy attachments
- Assume-role (trust) policies — which principal is allowed to assume a role
- OIDC federation — trusting GitHub's identity provider instead of long-lived AWS keys
- `sts:AssumeRoleWithWebIdentity`, `sts:AssumeRole`, `sts:TagSession`
- Least-privilege policy scoping (resource ARNs, `StringEquals`/`StringLike` conditions)
- Service-linked roles
- Caller identity / account ID lookups (`aws_caller_identity`)

**EKS (Elastic Kubernetes Service)**
- Control plane vs. worker nodes (managed node groups)
- EKS access entries & access policies (the current API-based auth model, replacing the older
  `aws-auth` ConfigMap approach)
- Separate IAM roles for the cluster (`eks.amazonaws.com` principal) vs. nodes
  (`ec2.amazonaws.com` principal)
- Required managed policies: `AmazonEKSClusterPolicy`, `AmazonEKSWorkerNodePolicy`,
  `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`
- Node group scaling config (min/max/desired) and capacity type (on-demand vs. spot)
- Resource creation/deletion ordering (`depends_on`) — IAM must exist before the cluster/node
  group, and must outlive them during teardown

**Storage / Remote State**
- S3 as a Terraform backend
- S3 native state locking (`use_lockfile`) as an alternative to the older DynamoDB-lock pattern
- Per-environment state isolation (separate bucket keys per environment)
- S3 bucket versioning, `force_destroy`

**Compute & Networking primitives**
- VPC, subnets, CIDR blocks, and subnet math (`cidrsubnet()`)
- Internet Gateway, route tables, route table associations
- Security groups and security group rules
- EC2 instance types (e.g., `t3.medium`)

**Core AWS mental model**
- Regions and Availability Zones (this project uses `af-south-1a/b/c`)
- Resource tagging and tag-based data source lookups (e.g. filtering `aws_vpc` by `tag:Name`)

## GitHub

- GitHub Actions workflow triggers (`pull_request`, `push`, `workflow_dispatch`)
- Matrix strategy — fanning a single job out across dev/qa/prd
- GitHub Environments — per-environment secrets/variables and approval gates
- OIDC federation from GitHub Actions to AWS (no static AWS credentials in the repo)
- Workflow permissions scoping (`id-token: write`, `contents: read`, `pull-requests: write`)
- Concurrency groups — preventing overlapping applies against the same environment
- `actions/github-script` — posting/updating the Terraform plan as a PR comment
- Repository/environment-level variables (e.g. `vars.AWS_ROLE_ARN`)
- Common reusable actions: `actions/checkout`, `hashicorp/setup-terraform`,
  `aws-actions/configure-aws-credentials`

## Networking

- VPC design and CIDR address planning
- Public vs. private subnets, and spreading subnets across multiple AZs
- Internet Gateway and the default route (`0.0.0.0/0`)
- Route tables and route table associations
- Security groups as stateful firewalls (ingress/egress, ports, protocols, CIDR sources)
- NodePort service exposure (port 30007) and why a matching security group rule is required
- Basic Kubernetes networking: Pod, Service, `NodePort` type, and the relationship between
  `port`, `targetPort`, and `nodePort`

## Supporting Terraform Concepts

- Remote backend configuration, including partial config via `-backend-config`
- Strategies for multi-environment layout (this project uses a directory-per-environment +
  `.tfvars` approach rather than Terraform workspaces)
- Modules and variable passing between root and module
- `.tfvars` files and `-var-file` for environment-specific values
- `locals` for derived naming conventions
- Provider version pinning (`required_providers`, `.terraform.lock.hcl`)
- The `fmt` → `validate` → `plan` → `apply` → `destroy` workflow
- The backend bootstrapping problem — why the OIDC trust role is provisioned in a separate,
  manually-applied `bootstrap/` state instead of the main project state
