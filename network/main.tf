terraform {
  #   #############################################################
  #   ## AFTER RUNNING TERRAFORM APPLY (WITH LOCAL BACKEND)
  #   ## YOU WILL UNCOMMENT THIS CODE THEN RERUN TERRAFORM INIT
  #   ## TO SWITCH FROM LOCAL BACKEND TO REMOTE AWS BACKEND
  #   #############################################################
  backend "s3" {
    bucket         = ""
    key            = "mlopspltf_infra/network/terraform.tfstate"
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
  region              = "us-east-1"
  allowed_account_ids = ["${var.allowed_account_id}"]
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name        = "mlopspltf-${var.environment}-vpc"
    project     = "MLOPSPLTF"
    environment = "${var.environment}"
    jira-ticket = "MLAIHO-31"
  }
}
