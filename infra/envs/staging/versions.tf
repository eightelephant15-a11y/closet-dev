terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State lives in S3. Create the bucket + lock table once (see infra/README.md), then
  # uncomment and fill in. Never commit state files.
  # backend "s3" {
  #   bucket         = "REPLACE-ME-terraform-state"
  #   key            = "stylist/staging/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "REPLACE-ME-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "stylist"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
