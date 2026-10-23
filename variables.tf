# All values are supplied per environment from envs/<env>/<env>.tfvars.
# Validation lives on the module variables where they are consumed.

variable "region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "prefix" {
  type        = string
  description = "Owner prefix used in resource names, e.g. trimm-st"
}

variable "environment" {
  type        = string
  description = "Environment name: dev, qa or prd"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource via provider default_tags"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version of the EKS control plane"
}

variable "subnets" {
  type        = map(string)
  description = "Map of availability zone => subnet CIDR block for this environment"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types for the node group"
}

variable "capacity_type" {
  type        = string
  description = "ON_DEMAND or SPOT"
}

variable "scaling_config" {
  type = object({
    min_size     = number
    max_size     = number
    desired_size = number
  })
  description = "Node group min/max/initial-desired size"
}

variable "node_port" {
  type        = number
  description = "NodePort opened on the cluster security group"
}

variable "node_port_ingress_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the NodePort"
}
