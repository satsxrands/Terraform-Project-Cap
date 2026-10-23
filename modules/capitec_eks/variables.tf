variable "prefix" {
  type        = string
  description = "Owner prefix used in every resource name, e.g. trimm-st"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.prefix))
    error_message = "prefix must be 3-20 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environment" {
  type        = string
  description = "Environment name; must be one of dev, qa or prd"

  validation {
    condition     = contains(["dev", "qa", "prd"], var.environment)
    error_message = "environment must be one of: dev, qa, prd."
  }
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version of the EKS control plane, e.g. 1.35"

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.cluster_version))
    error_message = "cluster_version must look like 1.35."
  }
}

variable "subnets" {
  type        = map(string)
  description = "Map of availability zone name => subnet CIDR block. EKS needs subnets in at least two AZs."

  validation {
    condition     = length(var.subnets) >= 2
    error_message = "subnets must define at least two availability zones (EKS requirement)."
  }

  validation {
    condition     = alltrue([for az in keys(var.subnets) : can(regex("^[a-z]{2}-[a-z]+-[0-9][a-z]$", az))])
    error_message = "Every subnets key must be an availability zone name such as af-south-1a."
  }

  validation {
    condition     = alltrue([for cidr in values(var.subnets) : can(cidrhost(cidr, 0))])
    error_message = "Every subnets value must be a valid IPv4 CIDR block."
  }
}

variable "capacity_type" {
  type        = string
  description = "Node capacity type: ON_DEMAND or SPOT"
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_port" {
  type        = number
  description = "Kubernetes NodePort opened on the cluster security group"

  validation {
    condition     = var.node_port >= 30000 && var.node_port <= 32767
    error_message = "node_port must be in the Kubernetes NodePort range 30000-32767."
  }
}

variable "node_port_ingress_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach node_port"

  validation {
    condition     = length(var.node_port_ingress_cidrs) > 0 && alltrue([for c in var.node_port_ingress_cidrs : can(cidrhost(c, 0))])
    error_message = "node_port_ingress_cidrs must be a non-empty list of valid CIDR blocks."
  }
}

locals {
  eks_cluster_name = "${var.prefix}-eks-${var.environment}"
  cluster_role     = "${var.prefix}-eks-iam-role-${var.environment}"
  node_role        = "${var.prefix}-eks-node-role-${var.environment}"
  node_group_name  = "${var.prefix}-eks-nodes-${var.environment}"
}
