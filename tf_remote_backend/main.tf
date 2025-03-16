terraform {
#   #############################################################
#   ## AFTER RUNNING TERRAFORM APPLY (WITH LOCAL BACKEND)
#   ## YOU WILL UNCOMMENT THIS CODE THEN RERUN TERRAFORM INIT
#   ## TO SWITCH FROM LOCAL BACKEND TO REMOTE AWS BACKEND
#   #############################################################
  backend "s3" {
    bucket         = ""
    key            = "mlopspltf_infra/tf_remote_backend/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = ""
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  allowed_account_ids = ["${var.allowed_account_id}"]
}

locals {
    tf_remote_backend_bucket_name = "${var.tf_remote_backend_bucket_name}"
    tf_remote_backend_ddb_table_name = "${var.tf_remote_backend_ddb_table_name}"
}

resource "aws_s3_bucket" "tf_remote_backend_bucket" {
  bucket        = local.tf_remote_backend_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "tf_remote_backend_bucket_versioning" {
  bucket = aws_s3_bucket.tf_remote_backend_bucket.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_remote_backend_bucket_crypto_conf" {
  bucket = aws_s3_bucket.tf_remote_backend_bucket.bucket 
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "tf_remote_backend_ddb_table" {
  name         = local.tf_remote_backend_ddb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}