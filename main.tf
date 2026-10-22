module "eks" {
  source = "./modules/capitec_eks"

  prefix                  = var.prefix
  environment             = var.environment
  cluster_version         = var.cluster_version
  subnets                 = var.subnets
  instance_types          = var.instance_types
  capacity_type           = var.capacity_type
  scaling_config          = var.scaling_config
  node_port               = var.node_port
  node_port_ingress_cidrs = var.node_port_ingress_cidrs
}
