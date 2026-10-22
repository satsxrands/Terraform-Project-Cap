terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial backend: bucket, key, region and locking are supplied per
  # environment with -backend-config=envs/<env>/<env>.tfbackend
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.tags, {
      Environment = var.environment
    })
  }
}
