terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}


provider "aws" {
  region = "us-east-1"
  alias  = "primary"
}

provider "aws" {
  region = "us-west-2"
  alias  = "secondary"
}

provider "helm" {
  alias = "primary"
  kubernetes {
    host                   = module.eks_primary.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_primary.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_primary.cluster_name]
    }
  }
}

provider "helm" {
  alias = "secondary"
  kubernetes {
    host                   = module.eks_secondary.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_secondary.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_secondary.cluster_name]
    }
  }
}

provider "kubernetes" {
  alias                  = "primary"
  host                   = module.eks_primary.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_primary.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_primary.cluster_name]
  }
}

provider "kubernetes" {
  alias                  = "secondary"
  host                   = module.eks_secondary.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_secondary.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_secondary.cluster_name]
  }
}

provider "kubectl" {
  alias                  = "primary"
  host                   = module.eks_primary.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_primary.cluster_certificate_authority_data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_primary.cluster_name]
  }
}

provider "kubectl" {
  alias                  = "secondary"
  host                   = module.eks_secondary.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_secondary.cluster_certificate_authority_data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_secondary.cluster_name]
  }
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
      instance_types = ["t3.small"]  # t3.micro gave issues for argocd deploy
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
      instance_types = ["t3.medium"]
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

module "gitops_primary" {
  source = "../../modules/gitops"
  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
    kubectl    = kubectl.primary
  }

  environment             = local.environment
  cluster_endpoint       = module.eks_primary.cluster_endpoint
  cluster_ca_certificate = module.eks_primary.cluster_certificate_authority_data
  git_repo_url          = "https://github.com/runatyr1/devops-cluster.git"
  git_revision          = "main"
  aws_region      = local.primary_region
  depends_on = [module.eks_primary]
}

module "gitops_secondary" {
  source = "../../modules/gitops"
  providers = {
    kubernetes = kubernetes.secondary
    helm       = helm.secondary
    kubectl    = kubectl.secondary
  }

  environment             = local.environment
  cluster_endpoint       = module.eks_secondary.cluster_endpoint
  cluster_ca_certificate = module.eks_secondary.cluster_certificate_authority_data
  git_repo_url          = "https://github.com/runatyr1/devops-cluster.git"
  git_revision          = "main"
  aws_region      = local.secondary_region
  depends_on = [module.eks_secondary]
}