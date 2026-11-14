locals {
  microsservicos_private_ingress = {
    execucao = {
      node_port         = 30081
      listener_port     = 8081
      target_group_name = "oficina-execucao-tg-dev"
    }
    orcamento_pagamento = {
      node_port         = 30082
      listener_port     = 8082
      target_group_name = "oficina-orcamento-tg-dev"
    }
  }
}

resource "aws_vpc_security_group_egress_rule" "nlb_to_microsservicos" {
  for_each = local.microsservicos_private_ingress

  security_group_id            = aws_security_group.api_internal_nlb.id
  referenced_security_group_id = module.eks.cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = each.value.node_port
  to_port                      = each.value.node_port
  description                  = "Permite NLB privado para NodePort ${each.value.node_port}."
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_microsservicos_nlb" {
  for_each = local.microsservicos_private_ingress

  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = aws_security_group.api_internal_nlb.id
  ip_protocol                  = "tcp"
  from_port                    = each.value.node_port
  to_port                      = each.value.node_port
  description                  = "Permite NLB privado no NodePort ${each.value.node_port}."
}

resource "aws_lb_target_group" "microsservicos_internal" {
  for_each = local.microsservicos_private_ingress

  name        = each.value.target_group_name
  port        = each.value.node_port
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = local.vpc_id

  health_check {
    protocol = "TCP"
  }

  tags = merge(local.api_private_ingress_tags, {
    Name         = each.value.target_group_name
    ResourceType = "TargetGroup"
    Service      = each.key
  })

  lifecycle {
    precondition {
      condition     = each.value.node_port != var.api_internal_node_port
      error_message = "API, Execução e Orçamento/Pagamento precisam de NodePorts distintos."
    }
  }
}

resource "aws_autoscaling_attachment" "microsservicos_internal" {
  for_each = local.microsservicos_private_ingress

  autoscaling_group_name = local.api_node_group_asg_name
  lb_target_group_arn    = aws_lb_target_group.microsservicos_internal[each.key].arn
}

resource "aws_lb_listener" "microsservicos_internal" {
  for_each = local.microsservicos_private_ingress

  load_balancer_arn = aws_lb.api_internal.arn
  port              = each.value.listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microsservicos_internal[each.key].arn
  }
}

resource "aws_ssm_parameter" "microsservicos_internal_node_port" {
  for_each = local.microsservicos_private_ingress

  name        = "${var.kubernetes_ssm_prefix}/${each.key}_internal_node_port"
  description = "NodePort contratual exclusivo do serviço ${each.key}."
  type        = "String"
  value       = tostring(each.value.node_port)
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "microsservicos_internal_nlb_listener_arn" {
  for_each = local.microsservicos_private_ingress

  name        = "${var.kubernetes_ssm_prefix}/${each.key}_internal_nlb_listener_arn"
  description = "Listener privado do serviço ${each.key}, consumido pelo API Gateway."
  type        = "String"
  value       = aws_lb_listener.microsservicos_internal[each.key].arn
  tags        = local.common_tags
}

output "microsservicos_private_ingress" {
  description = "Contratos não secretos dos ingressos privados; não comprovam aplicação implantada."
  value = {
    for servico, contrato in local.microsservicos_private_ingress : servico => {
      node_port              = contrato.node_port
      listener_port          = contrato.listener_port
      listener_arn           = aws_lb_listener.microsservicos_internal[servico].arn
      target_group_arn       = aws_lb_target_group.microsservicos_internal[servico].arn
      nlb_arn                = aws_lb.api_internal.arn
      nlb_security_group_id  = aws_security_group.api_internal_nlb.id
      node_security_group_id = module.eks.cluster_security_group_id
    }
  }
}
