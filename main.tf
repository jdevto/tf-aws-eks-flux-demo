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

# Flux Module - Installs Flux only
module "flux" {
  source = "./modules/flux"

  depends_on = [module.eks]
}

# Flux Workloads Module - Bootstraps GitRepository and Kustomizations
module "flux_workloads" {
  source = "./modules/flux-workloads"

  repo_url      = var.repo_url
  repo_branch   = var.repo_branch
  sync_interval = var.flux_sync_interval

  flux_namespace = module.flux.flux_namespace
  flux_ready     = module.flux.flux_release_name

  workloads = [
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
      path = "k8s-app/podinfo"
    },
    {
      name = "weave-gitops"
      path = "k8s-app/weave-gitops"
    }
  ]

  depends_on = [module.flux]
}
