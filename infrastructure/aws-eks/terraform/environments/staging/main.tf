
provider "aws" {
  region = "us-east-1"
  alias  = "primary"
}

provider "aws" {
  region = "us-west-2"
  alias  = "secondary"
}

locals {
  primary_region   = "us-east-1"
  secondary_region = "us-west-2"
  environment      = "staging"
  cluster_version  = "1.32"
  
  # Primary VPC configuration
  primary_vpc_cidr = "10.0.0.0/16"
  primary_azs      = ["${local.primary_region}a", "${local.primary_region}b"]
  primary_private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  primary_public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  
  # Secondary VPC configuration
  secondary_vpc_cidr = "10.1.0.0/16"
  secondary_azs      = ["${local.secondary_region}a", "${local.secondary_region}b"]  # Need both AZs for EKS
  secondary_private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  secondary_public_subnets  = ["10.1.101.0/24", "10.1.102.0/24"]
  
  tags = {
    Project     = "eks-demo"
    Environment = local.environment
  }
}


# Primary region network
module "network_primary" {
  source = "../../modules/network"
  providers = {
    aws = aws.primary
  }

  environment        = local.environment
  aws_region        = local.primary_region
  vpc_cidr          = local.primary_vpc_cidr
  availability_zones = local.primary_azs
  private_subnets   = local.primary_private_subnets
  public_subnets    = local.primary_public_subnets
  tags              = local.tags
}


# Secondary region network
module "network_secondary" {
  source = "../../modules/network"
  providers = {
    aws = aws.secondary
  }

  environment        = local.environment
  aws_region        = local.secondary_region
  vpc_cidr          = local.secondary_vpc_cidr
  availability_zones = local.secondary_azs
  private_subnets =  local.secondary_private_subnets
  public_subnets    = local.secondary_public_subnets
  tags              = local.tags
}

# VPC Peering
module "vpc_peering" {
  source = "../../modules/vpc-peering"
  providers = {
    aws.requester = aws.primary
    aws.accepter  = aws.secondary
  }
  environment = local.environment
  peer_region = local.secondary_region
  requester_vpc_id = module.network_primary.vpc_id
  accepter_vpc_id  = module.network_secondary.vpc_id
  tags            = local.tags
}

# Primary region EKS
module "eks_primary" {
  source = "../../modules/eks"
  providers = {
    aws = aws.primary
  }
  depends_on = [module.network_primary]

  environment      = local.environment
  cluster_version  = local.cluster_version
  vpc_id          = module.network_primary.vpc_id
  private_subnets = module.network_primary.private_subnets
  tags            = local.tags

  node_groups = {
    main = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.micro"]
      labels = {
        Environment = local.environment
      }
    }
  }

  enable_irsa = true
  authentication_mode = "API"
  cluster_endpoint_public_access = true
}

# Secondary region EKS
module "eks_secondary" {
  source = "../../modules/eks"
  providers = {
    aws = aws.secondary
  }
  depends_on = [module.network_secondary]

  environment      = local.environment
  cluster_version  = local.cluster_version
  vpc_id          = module.network_secondary.vpc_id
  private_subnets = module.network_secondary.private_subnets 
  tags            = local.tags

  node_groups = {
    main = {
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = ["t3.micro"]
      subnet_ids     = [module.network_secondary.private_subnets[0]]
      labels = {
        Environment = local.environment
      }
    }
  }

  enable_irsa = true
  authentication_mode = "API"
  cluster_endpoint_public_access = true
}
