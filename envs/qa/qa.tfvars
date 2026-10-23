region      = "af-south-1"
prefix      = "trimm-st"
environment = "qa"

tags = {
  APP       = "capitec-terraform-training"
  OWNER     = "Geeks4Learning"
  DEVELOPER = "trimm-st"
}

cluster_version = "1.35"

# Subnets are carved from the reserved block 172.31.148.0/22 (see learner_subnets).
# Each environment gets its own non-overlapping /25 ranges so all three can
# live side by side in the shared default VPC.
subnets = {
  "af-south-1a" = "172.31.149.0/25"
  "af-south-1b" = "172.31.149.128/25"
}

capacity_type = "ON_DEMAND"

node_port               = 30007
node_port_ingress_cidrs = ["0.0.0.0/0"]
