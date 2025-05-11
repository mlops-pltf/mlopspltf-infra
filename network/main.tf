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
  region = "us-east-1"
}


resource "aws_vpc" "main" {
  cidr_block       = var.environment == "tst" ? "20.0.0.0/16" : "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name        = "mlopspltf-${var.environment}-vpc"
    project     = "MLOPSPLTF"
    environment = "${var.environment}"
    jira-ticket = "MLAIHO-31"
  }
}


resource "aws_internet_gateway" "mlopspltf_internet_gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "mlopspltf-${var.environment}-igw"
    project     = "MLOPSPLTF"
    environment = "${var.environment}"
    jira-ticket = "MLAIHO-57"
  }
}


resource "aws_route_table" "mlopspltf_route_table_with_igw" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = aws_vpc.main.cidr_block
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mlopspltf_internet_gateway.id
  }

  tags = {
    Name        = "mlopspltf-${var.environment}-rt-with-igw"
    project     = "MLOPSPLTF"
    environment = "${var.environment}"
    jira-ticket = "MLAIHO-57"
  }
}


resource "aws_subnet" "mlopspltf_public_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.environment == "tst" ? "20.0.0.0/26" : "10.0.0.0/26"

  tags = {
    Name        = "mlopspltf-${var.environment}-public-subnet-1"
    project     = "MLOPSPLTF"
    environment = "${var.environment}"
    jira-ticket = "MLAIHO-57"
  }
}


resource "aws_route_table_association" "mlopspltf_public_subnet_1_rt_associaton" {
  subnet_id      = aws_subnet.mlopspltf_public_subnet_1.id
  route_table_id = aws_route_table.mlopspltf_route_table_with_igw.id
}


resource "aws_security_group" "mloppltf_ollama_node_security_group" {
  name        = "mloppltf_${var.environment}_ollama_node_sg"
  description = "Allow required traffic for ollma inference node"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "mloppltf_${var.environment}_ollama_node_sg"
    project     = "MLOPSPLTF"
    environment = "${var.environment}"
    jira-ticket = "MLAIHO-57"
  }
}

resource "aws_security_group_rule" "ingress_sg_rule_allow_all_traffic_originated_from_my_mac" {
  type              = "ingress"
  security_group_id = aws_security_group.mloppltf_ollama_node_security_group.id
  cidr_blocks       = [var.my_mac_cidr]
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
}

resource "aws_security_group_rule" "ingress_sg_rule_allow_all_ipv4_traffic_originated_within_vpc" {
  type              = "ingress"
  security_group_id = aws_security_group.mloppltf_ollama_node_security_group.id
  cidr_blocks       = [aws_vpc.main.cidr_block]
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
}

resource "aws_security_group_rule" "egress_sg_rule_allow_all_traffic_ipv4" {
  type              = "egress"
  security_group_id = aws_security_group.mloppltf_ollama_node_security_group.id
  cidr_blocks       = ["0.0.0.0/0"]
  protocol          = "-1" # semantically equivalent to all ports
  from_port         = 0
  to_port           = 0
}