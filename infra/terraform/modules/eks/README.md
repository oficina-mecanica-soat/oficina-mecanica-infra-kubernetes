# ☸️ EKS Module

## 🎯 Objetivo

Este módulo provisiona o cluster Amazon EKS e o Managed Node Group usados para executar a API no ambiente AWS Academy.

## 📦 Recursos criados

- Amazon EKS Cluster
- Amazon EKS Managed Node Group
- Metrics Server como add-on do EKS, necessário para os HPAs consultarem CPU e memória
- Referências a IAM Roles existentes no laboratório

As roles não são criadas por este módulo. Elas devem existir no AWS Academy e ser informadas pelo ambiente:

```powershell
$env:TF_VAR_eks_cluster_role_name = "<LabEksClusterRole-...>"
$env:TF_VAR_eks_node_role_name = "<LabEksNodeRole-...>"
```

## 🎓 Decisões para AWS Academy

- Os nós usam subnets privadas.
- O endpoint privado do cluster fica habilitado.
- O endpoint público fica habilitado para facilitar a operação no laboratório.
- O ambiente `dev` limita o Node Group a `desired_size = 2`, `min_size = 1` e `max_size = 2` para evitar crescimento de custo.
- O Metrics Server usa uma réplica nesse node único; a versão `v0.8.1-eksbuild.24` foi conferida na API EKS para Kubernetes 1.33. Não substitui Datadog, histórico de métricas ou a validação de capacidade para escalar workloads.

## 🔒 Endurecimento recomendado

Antes de aplicar em AWS, restrinja `cluster_endpoint_public_access_cidrs` para o IP público autorizado quando possível:

```hcl
cluster_endpoint_public_access_cidrs = ["203.0.113.10/32"]
```

Ao final da janela autorizada, executar o destroy pela esteira oficial, respeitando as dependências e a preservação das evidências. Não executar apply/destroy local.
