mock_provider "aws" {}

override_resource {
  target          = aws_security_group.api_internal_nlb
  override_during = plan
  values          = { id = "sg-11111111111111111" }
}

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

run "ingressos_privados_isolam_portas_e_preservam_api" {
  command = plan
  assert {
    condition = (
      aws_lb.api_internal.internal &&
      aws_lb_listener.api_internal.port == 80 &&
      aws_lb_listener.microsservicos_internal["execucao"].port == 8081 &&
      aws_lb_listener.microsservicos_internal["orcamento_pagamento"].port == 8082 &&
      aws_lb_target_group.microsservicos_internal["execucao"].port == 30081 &&
      aws_lb_target_group.microsservicos_internal["orcamento_pagamento"].port == 30082 &&
      aws_ssm_parameter.microsservicos_internal_node_port["orcamento_pagamento"].value == "30082" &&
      aws_ssm_parameter.microsservicos_internal_nlb_listener_arn["execucao"].name == "/oficina-mecanica/development/kubernetes/execucao_internal_nlb_listener_arn"
    )
    error_message = "Listeners privados devem preservar a API e separar os novos owners."
  }
  assert {
    condition     = alltrue([for regra in aws_vpc_security_group_ingress_rule.nodes_from_microsservicos_nlb : regra.referenced_security_group_id == "sg-11111111111111111"])
    error_message = "NodePorts novos devem aceitar somente o SG do NLB, sem CIDR público."
  }
}
run "colisao_com_nodeport_da_api_bloqueia_plano" {
  command = plan
  variables { api_internal_node_port = 30081 }
  expect_failures = [aws_lb_target_group.microsservicos_internal]
}
