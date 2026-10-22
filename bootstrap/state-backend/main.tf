####################################################################
# One-time bootstrap: remote state buckets for dev, qa and prd
#
# Applied manually, once, with local state - the main project cannot create
# its own backend because it needs the bucket to exist before `init`.
#   cd bootstrap/state-backend
#   terraform init
#   terraform apply -var="prefix=trimm-st"
####################################################################

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

resource "aws_s3_bucket" "state" {
  for_each = toset(var.environments)

  bucket = "${var.prefix}-s3-${each.key}"

  # State buckets are never force-destroyed: removing one loses the record of
  # that environment's infrastructure.
  force_destroy = false

  tags = {
    Environment = each.key
  }
}

resource "aws_s3_bucket_versioning" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  for_each = aws_s3_bucket.state

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
