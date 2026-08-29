############################################
# Remote state backend.
#
# IMPORTANT: Run `terraform apply` in ../../bootstrap FIRST, then
# fill in the value below from its output:
#   terraform -chdir=../../bootstrap output state_bucket_name
#
# Terraform will NOT let you interpolate variables here — backend
# config must be literal values. That's a Terraform limitation,
# not a mistake.
#
# LOCKING: use_lockfile=true enables S3-native state locking (GA
# since Terraform 1.11, uses S3 conditional writes under the hood).
# No DynamoDB table required — the old dynamodb_table argument is
# deprecated in favor of this.
############################################

terraform {
  backend "s3" {
    bucket       = "devops-8byte-tfstate-7bdf19b0"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
