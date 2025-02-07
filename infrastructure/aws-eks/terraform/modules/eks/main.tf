locals {
  cluster_name = "${var.environment}-eks"
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# module docs: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.33.1"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  vpc_id         = var.vpc_id
  subnet_ids     = var.private_subnets
  tags           = local.common_tags
  
  eks_managed_node_groups = var.node_groups
  
  enable_irsa                     = var.enable_irsa
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  
  access_entries = {
    sso_admin = {
      principal_arn = "arn:aws:iam::473340819522:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_5a6fca4d93954578"
      type         = "STANDARD"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

}




# This was disabled as the upstream (default) terraform modules cofnigure it by default
# It was causing and was causing duplicate issues. Leaving as comment for further analysis. 
#resource "aws_iam_role_policy" "cluster_policy" {
#  name = "${local.cluster_name}-policy"
#  role = module.eks.cluster_iam_role_name
#
#  policy = jsonencode({
#    Version = "2012-10-17"
#    Statement = [
#      {
#        Effect = "Allow"
#        Action = [
#          "eks:*",
#          "ec2:DescribeInstances",
#          "iam:PassRole"
#        ]
#        Resource = "*"
#      }
#    ]
#  })
#}
#
#resource "aws_iam_role_policies_exclusive" "cluster_policies" {
#  role_name     = module.eks.cluster_iam_role_name
#  policy_names  = [aws_iam_role_policy.cluster_policy.name]
#  depends_on    = [aws_iam_role_policy.cluster_policy]
#}