terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version              = ">= 5.0"
      configuration_aliases = [aws] 
    }
  }
}

locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.18.1"

  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.environment != "prod"
  enable_dns_hostnames   = true
  enable_dns_support     = true

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.environment}-eks" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.environment}-eks" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  tags = local.common_tags
}

resource "aws_route" "private_peering_route" {
  count = var.peer_vpc_cidr != "" ? length(module.vpc.private_route_table_ids) : 0

  route_table_id            = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block    = var.peer_vpc_cidr
  vpc_peering_connection_id = var.vpc_peering_connection_id
}

resource "aws_route" "public_peering_route" {
  count = var.peer_vpc_cidr != "" ? length(module.vpc.public_route_table_ids) : 0

  route_table_id            = module.vpc.public_route_table_ids[count.index]
  destination_cidr_block    = var.peer_vpc_cidr
  vpc_peering_connection_id = var.vpc_peering_connection_id
}