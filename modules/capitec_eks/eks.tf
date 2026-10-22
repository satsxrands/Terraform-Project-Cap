data "aws_partition" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# Networking: one public subnet per AZ in the shared default VPC
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = var.subnets

  vpc_id                  = data.aws_vpc.default.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = {
    Name                                              = "${var.prefix}-subnet-${var.environment}-${each.key}"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
  }

  lifecycle {
    precondition {
      condition     = contains(data.aws_availability_zones.available.names, each.key)
      error_message = "${each.key} is not an available availability zone in the configured region."
    }
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = data.aws_vpc.default.main_route_table_id
}

# ---------------------------------------------------------------------------
# Control plane
# ---------------------------------------------------------------------------
resource "aws_iam_role" "cluster" {
  name               = local.cluster_role
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_eks_cluster" "main" {
  name     = local.eks_cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  # API mode: Kubernetes access is governed by EKS access entries. The
  # principal that creates the cluster is granted cluster-admin through the
  # bootstrap flag, so no separate access entry for the caller is needed.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids = [for s in aws_subnet.public : s.id]
  }

  # IAM must exist before, and outlive, the cluster so EKS can clean up the
  # security groups and ENIs it manages.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
}

# ---------------------------------------------------------------------------
# Worker nodes
# ---------------------------------------------------------------------------
resource "aws_iam_role" "node" {
  name               = local.node_role
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

resource "aws_security_group_rule" "nodeport_ingress" {
  type              = "ingress"
  from_port         = var.node_port
  to_port           = var.node_port
  protocol          = "tcp"
  cidr_blocks       = var.node_port_ingress_cidrs
  security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  description       = "Allow inbound access to the NodePort service"
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = local.node_group_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [for s in aws_subnet.public : s.id]

  capacity_type  = var.capacity_type
  instance_types = var.instance_types

  scaling_config {
    min_size     = var.scaling_config.min_size
    max_size     = var.scaling_config.max_size
    desired_size = var.scaling_config.desired_size
  }

  update_config {
    max_unavailable = 1
  }

  # The cluster autoscaler owns desired_size after creation; without this
  # every apply would reset it back to the tfvars value.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  # IAM permissions must exist before, and be deleted after, the node group.
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}
