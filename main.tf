# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name               = var.cluster_name
  cluster_name       = var.cluster_name
  availability_zones = ["${var.region}a", "${var.region}b"]

  tags = merge(local.common_tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  # Cluster control plane can use both public and private subnets
  subnet_ids = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  # Node groups should be in private subnets only for security
  node_subnet_ids = module.vpc.private_subnet_ids
  vpc_id          = module.vpc.vpc_id
  tags            = local.common_tags

  depends_on = [module.vpc]
}

# Flux Module - Installs Flux and bootstraps workloads
module "flux" {
  source = "./modules/flux"

  weave_gitops_username = var.weave_gitops_username

  # Workloads configuration
  repo_url      = var.repo_url
  repo_branch   = var.repo_branch
  sync_interval = var.flux_sync_interval

  workloads = [
    {
      name = "weave-gitops"
      path = "k8s-app/weave-gitops"
    },
    {
      name = "welcome"
      path = "k8s-app/welcome"
    },
    {
      name = "simple-app"
      path = "k8s-app/simple-app"
    },
    {
      name = "podinfo-dev"
      path = "k8s-app/podinfo/dev"
    },
    {
      name = "podinfo-staging"
      path = "k8s-app/podinfo/staging"
    },
    {
      name = "podinfo-prod"
      path = "k8s-app/podinfo/prod"
    }
  ]

  depends_on = [module.eks]
}

