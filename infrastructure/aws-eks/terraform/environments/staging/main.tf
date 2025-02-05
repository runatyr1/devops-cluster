provider "aws" {
  region = local.region
}

locals {
  region = "us-east-1"
  environment = "staging"
  
  vpc_cidr = "10.0.0.0/16"
  azs      = ["${local.region}a", "${local.region}b"]
  
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  
  tags = {
    Project     = "eks-demo"
    Environment = local.environment
  }
}

module "network" {
  source = "../../modules/network"

  environment        = local.environment
  aws_region        = local.region
  vpc_cidr          = local.vpc_cidr
  availability_zones = local.azs
  private_subnets   = local.private_subnets
  public_subnets    = local.public_subnets
  tags              = local.tags
}