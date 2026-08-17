# Remote state with locking. State contains plaintext secrets, so the bucket
# is encrypted, versioned and private, and it is never committed to git.
terraform {
  backend "s3" {
    bucket       = "tiffin-tfstate-ap-south-1"
    key          = "prod/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true # S3-native locking; replaces the DynamoDB table
  }
}
