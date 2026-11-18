resource "aws_eks_cluster" "this" {
  name    = var.cluster_name
  version = var.cluster_version

  role_arn = data.aws_iam_role.eks_cluster.arn

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids = var.private_subnet_ids

    endpoint_private_access = true
    endpoint_public_access  = true

    public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  }

  tags = merge(
    var.tags,
    {
      Name = "oficina-mecanica-eks"
    }
  )
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "metrics-server"
  addon_version = "v0.8.1-eksbuild.24"

  # Uma réplica atende ao node único do laboratório, sem ampliar a infraestrutura.
  configuration_values = jsonencode({ replicas = 1 })

  tags = var.tags

  depends_on = [aws_eks_node_group.this]
}
