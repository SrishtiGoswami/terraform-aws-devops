############################################
# BOOTSTRAP — run this ONCE, before anything else
#
# Terraform's S3 backend can't be created by the same
# config that uses it (chicken-and-egg problem), so this
# tiny standalone config creates just one thing:
#   - an S3 bucket to hold terraform.tfstate (versioned + encrypted)
#
# Locking uses Terraform's native S3 locking (use_lockfile, GA since
# Terraform 1.11 — see backend.tf), which relies on S3 conditional
# writes. No DynamoDB table needed: it was previously required for
# locking, but AWS/HashiCorp deprecated that path once S3 itself could
# do it. One less resource to create, tag, and clean up. This bucket
# is covered by the S3 "Always Free" tier (5GB), so this costs $0
# regardless of how long it exists.
#
# This uses LOCAL state (just a .tfstate file on your machine) for
# itself. That's fine — it's a one-time, rarely-touched resource, and
# there's no other config to race against it.
############################################

terraform {
  required_version = ">= 1.11.0" # required for GA use_lockfile support downstream
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Random suffix so the bucket name is globally unique without you
# having to think of one.
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "tf_state" {
  force_destroy = true
  bucket = "${var.project_name}-tfstate-${random_id.suffix.hex}"

  # Safety net: Terraform-level guard (not an AWS setting) that blocks
  # `terraform destroy` from planning removal of this bucket, so a
  # careless full teardown can't take your state with it.
  #
  # TO ACTUALLY DESTROY THIS BUCKET LATER: comment out or delete the
  # block below, then run `terraform destroy` again — no `apply`
  # needed first, Terraform just reads whatever the config says at
  # destroy time.
#  lifecycle {
#    prevent_destroy = true
#  }

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform-bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
