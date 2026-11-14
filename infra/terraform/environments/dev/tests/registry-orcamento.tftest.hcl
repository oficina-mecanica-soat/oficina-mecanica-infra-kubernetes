mock_provider "aws" {}

override_module {
  target = module.eks
  outputs = {
    cluster_name                      = "oficina-mecanica-eks-dev"
    cluster_endpoint                  = "https://eks.exemplo.local"
    cluster_security_group_id         = "sg-0123456789abcdef0"
    node_group_name                   = "oficina-mecanica-node-group-dev"
    node_group_autoscaling_group_name = "asg-teste"
  }
}

override_data {
  target = data.aws_ssm_parameter.vpc_id
  values = { value = "vpc-0123456789abcdef0" }
}

override_data {
  target = data.aws_ssm_parameter.private_subnet_ids
  values = { value = "subnet-0123456789abcdef0,subnet-0123456789abcdef1" }
}

override_resource {
  target          = module.ecr_orcamento_pagamento.aws_ecr_repository.this
  override_during = plan
  values          = { repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/oficina-mecanica-orcamento-pagamento" }
}

variables {
  eks_cluster_role_name = "LabRole"
  eks_node_role_name    = "LabRole"
}

run "registries_isolados_preservam_politicas_e_contratos" {
  command = plan

  assert {
    condition = (
      output.ecr_repository_name == "oficina-mecanica-api" &&
      output.execucao_ecr_repository_name == "oficina-mecanica-execucao" &&
      output.orcamento_pagamento_ecr_repository_name == "oficina-mecanica-orcamento-pagamento"
    )
    error_message = "Os três serviços precisam de registries distintos, preservando os nomes existentes."
  }

  assert {
    condition = (
      aws_ssm_parameter.orcamento_pagamento_ecr_repository_name.name == "/oficina-mecanica/development/kubernetes/orcamento_pagamento_ecr_repository_name" &&
      aws_ssm_parameter.orcamento_pagamento_ecr_repository_name.value == output.orcamento_pagamento_ecr_repository_name &&
      aws_ssm_parameter.orcamento_pagamento_ecr_repository_url.value == output.orcamento_pagamento_ecr_repository_url &&
      aws_ssm_parameter.orcamento_pagamento_ecr_repository_url.type == "String"
    )
    error_message = "Os contratos SSM do registry devem refletir os outputs próprios."
  }
}
