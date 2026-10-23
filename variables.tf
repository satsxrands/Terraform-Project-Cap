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

variable "capacity_type" {
  type        = string
  description = "ON_DEMAND or SPOT"
}

variable "node_port" {
  type        = number
  description = "NodePort opened on the cluster security group"
}

variable "node_port_ingress_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the NodePort"
}
