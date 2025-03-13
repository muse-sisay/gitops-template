locals {
  vpc_cidr = "10.0.0.0/16"
  pod_cidr = "100.64.0.0/16"
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.2"

  name = local.name
  cidr = local.vpc_cidr

  azs = local.azs
  private_subnets = concat(
    [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)],
  [for k, v in local.azs : cidrsubnet(local.pod_cidr, 4, k)])

  public_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_ipv6            = false
  create_egress_only_igw = true

  public_subnet_ipv6_prefixes  = [0, 1, 2]
  private_subnet_ipv6_prefixes = [3, 4, 5]
  intra_subnet_ipv6_prefixes   = [6, 7, 8]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}


resource "kubernetes_manifest" "eni_config" {
  for_each = zipmap(local.azs, slice(module.vpc.private_subnets, 3, 6))

  manifest = yamlencode({
    "apiVersion" = "crd.k8s.amazonaws.com/v1alpha1"
    "kind"       = "ENIConfig"
    "metadata" = {
      "name" = "${each.key}"
    }
    "spec" = {
      "securityGroups" = [
        module.eks.node_security_group_id,
      ]
      "subnet" = "${each.value}"
    }
  })
  depends_on = [module.eks]
}
