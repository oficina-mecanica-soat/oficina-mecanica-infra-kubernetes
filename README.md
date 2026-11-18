# ☸️ Oficina Mecânica Infra Kubernetes

Plataforma compartilhada: EKS, nodes, três repositórios ECR, NLB/listeners privados e Datadog Agent/Cluster Agent. Os workloads são implantados pelas esteiras das aplicações.

## 🏗️ Recursos provisionados por esta esteira

| Escopo | Recursos criados ou configurados | Consumidores |
| --- | --- | --- |
| Computação compartilhada | Cluster EKS, Managed Node Group e add-on Metrics Server | Os três microsserviços e componentes da plataforma |
| Rede privada compartilhada | Um NLB interno, security group e regras de tráfego entre NLB e nodes | API Gateway via VPC Link |
| OS / API | ECR `oficina-mecanica-api`, target group, associação ao grupo de nodes e listener TCP/80 → NodePort 30080 | Deploy da API e integração privada de OS no Gateway |
| Execução | ECR `oficina-mecanica-execucao`, target group próprio, associação ao grupo de nodes e listener TCP/8081 → NodePort 30081 | Deploy do Execução e integração privada de Execução no Gateway |
| Orçamento/Pagamento | ECR `oficina-mecanica-orcamento-pagamento`, target group próprio, associação ao grupo de nodes e listener TCP/8082 → NodePort 30082 | Deploy de Orçamento/Pagamento e integração privada correspondente no Gateway |
| Contratos | Parâmetros SSM de EKS, registries, listeners, NodePorts e prontidão da plataforma | Esteiras RDS, aplicações, Auth e Gateway |
| Observabilidade | Datadog Agent e Cluster Agent instalados/configurados por Helm no workflow `datadog-observability.yml`, chamado pelo CD | Métricas de Kubernetes, coleta de logs e recepção de traces dos serviços |

Os nomes dos ECRs acima são os padrões configuráveis do ambiente. O NLB e o EKS são compartilhados; os três ECRs, listeners e target groups são distintos. Esta esteira cria os registries, mas **as esteiras das aplicações publicam as imagens**.

### 🔎 O que pertence às esteiras dos microsserviços

| Esteira | Recursos que ela provisiona no ambiente compartilhado |
| --- | --- |
| [API / OS](https://github.com/oficina-mecanica-soat/oficina-mecanica-api) | Namespace, Deployment, ConfigMap, Secret, Service NodePort e HPA da API; entrada FIFO, DLQ e contratos de OS |
| [Execução](https://github.com/oficina-mecanica-soat/oficina-mecanica-execucao) | Namespace, Deployment, Secret e Service NodePort de Execução; tabela DynamoDB, entrada FIFO, DLQ e contratos próprios; não cria ConfigMap ou HPA no Terraform atual |
| [Orçamento/Pagamento](https://github.com/oficina-mecanica-soat/oficina-mecanica-orcamento-pagamento) | Namespace, Deployment, ConfigMap, Secret, Service NodePort e HPA do serviço; entrada FIFO, DLQ e contratos próprios |

Bancos SQL e logins são preparados pela [esteira RDS](https://github.com/oficina-mecanica-soat/oficina-mecanica-infra-rds). A função de autenticação e as rotas públicas pertencem às esteiras Auth e Gateway. Esta esteira Kubernetes não substitui esses provisionamentos nem instala as aplicações de negócio por conta própria.

Fontes: [módulos EKS/ECR](infra/terraform/environments/dev/main.tf), [ingresso privado de OS](infra/terraform/environments/dev/private-ingress.tf), [ingressos dos participantes](infra/terraform/environments/dev/microsservicos-private-ingress.tf) e [workflow Datadog](.github/workflows/datadog-observability.yml).

<a id="registries-e-ingresso-privado"></a>

## 📦 Registries e ingresso privado

Os ECRs da API, Execução e Orçamento/Pagamento pertencem a esta esteira; cada aplicação publica sua imagem. Contratos em `/oficina-mecanica/development/kubernetes/` incluem `cluster_name`, `cluster_endpoint`, `cluster_security_group_id`, `node_group_name`, `ecr_repository_url`, `execucao_ecr_repository_url` e `orcamento_pagamento_ecr_repository_url`.

Listeners privados: OS 80 → NodePort 30080; Execução 8081 → 30081; Orçamento/Pagamento 8082 → 30082. Gateway usa VPC Link. Não há acesso público direto ao workload.

LabRole é compartilhada no ambiente acadêmico. Os nodes usam IMDSv2 obrigatório e hop limit 2 para a identidade dos workloads; isso não fornece isolamento IAM por aplicação. Após retomar o laboratório, a recuperação é feita pela própria esteira, sem alteração manual dos nodes.


## 🌐 Dependência da VPC

Antes de aplicar Kubernetes, a VPC precisa estar pronta e publicar os parâmetros abaixo:

| Parâmetro SSM | Uso |
| --- | --- |
| `/oficina-mecanica/development/status/vpc` | Deve estar com valor `ready`. |
| `/oficina-mecanica/development/vpc/vpc_id` | VPC usada pelo EKS. |
| `/oficina-mecanica/development/vpc/private_subnet_ids` | Subnets privadas usadas pelo cluster e pelo node group. |

## 🔐 Variáveis e secrets

Configurar no GitHub Environment `development` antes do primeiro merge para `develop` que execute deploy real.

Environment secrets:

| Nome | Uso |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | Credencial AWS Academy. |
| `AWS_SECRET_ACCESS_KEY` | Credencial AWS Academy. |
| `AWS_SESSION_TOKEN` | Token de sessão AWS Academy. |

Environment variables:

| Nome | Valor sugerido |
| --- | --- |
| `AWS_DEPLOY_ENABLED` | `false` enquanto o laboratório estiver encerrado; `true` somente na janela autorizada. Definir no nível do repositório para o detector de CD. |
| `AWS_REGION` | `us-east-1` |
| `EKS_CLUSTER_ROLE_NAME` | `LabRole` quando o lab usar role única, ou a role EKS indicada pela AWS Academy. |
| `EKS_NODE_ROLE_NAME` | `LabRole` quando o lab usar role única, ou a role de nodes indicada pela AWS Academy. |
| `AUTO_PR_ENABLED` | `true` somente quando quiser abrir PRs automáticos de promoção. |
| `RELEASE_BRANCH` | `release` |
| `DD_SITE` | Site Datadog da organização, por exemplo `datadoghq.com`. |

Environment secret adicional:

| Nome | Uso |
| --- | --- |
| `DD_API_KEY` | API key do Datadog usada na instalação do Agent; criar em **Settings > Environments > development > Environment secrets**. |

`DD_SITE` deve ser criado em **Settings > Environments > development > Environment variables**. O valor real de `DD_API_KEY` nunca deve ser versionado.

### Painéis por assunto e serviço

- **[Infraestrutura](https://app.datadoghq.com/dashboard/axy-gix-3kr)** — [`infraestrutura-dashboard.json`](observability/datadog/infraestrutura-dashboard.json): CPU, memória, réplicas e reinícios em grupos separados para OS/API, Execução e Orçamento/Pagamento; disponibilidade da plataforma em grupo próprio. O escopo atual é Kubernetes; RDS/SQS exigem integração AWS e não são apresentados como gráficos vazios.
- **[Aplicações](https://app.datadoghq.com/dashboard/2g5-62n-jci)** — [`aplicacoes-dashboard.json`](observability/datadog/aplicacoes-dashboard.json): tráfego HTTP, latência p95, eventos da aplicação e diagnóstico das bibliotecas por serviço; traces e IDs da Saga em grupo transversal. `hits` conta requisições, incluindo healthchecks, não ordens de serviço únicas.

As definições usam grupos nativos do Datadog e podem ser importadas em **Configure → Import dashboard JSON**. Preserve o histórico e confira o dashboard de destino antes de substituir seu conteúdo.

Fontes: [métricas Kubernetes](https://docs.datadoghq.com/containers/kubernetes/data_collected/) e [métricas APM](https://docs.datadoghq.com/tracing/metrics/metrics_namespace/). CPU está em nanocores e memória em bytes. A métrica `duration` legada não deve ser usada para percentis.

A origem do logger é identificada por `Properties.SourceContext`, mantendo a mensagem original das bibliotecas. Eventos próprios e avisos/erros de bibliotecas possuem streams distintos; SQL rotineiro não é apresentado como evento de negócio. A convenção de emissão está na [RFC-0006](https://github.com/oficina-mecanica-soat/oficina-mecanica-api/blob/develop/docs/architecture/rfcs/rfc-0006-observabilidade-centralizada-com-datadog.md).

A validação no CI confere estrutura, fontes/escopo e agregações; não cria ou importa o painel nem comprova ingestão. Conferir nomes de operação, tags, conta/cluster, versão e intervalo no ambiente real. Réplicas disponíveis não substituem health funcional; ausência de telemetria não significa zero erros. Alertas precisam de baseline e teste de disparo/recuperação, conforme o [roteiro de referência](https://github.com/oficina-mecanica-soat/oficina-mecanica-api/blob/develop/docs/deploy/deploy-aws.md).

## 🧪 Execução local

Validar formatação:

```powershell
terraform fmt -check -recursive infra/terraform
```

Validar Terraform:

```powershell
terraform -chdir=infra/terraform/environments/dev init -backend=false
terraform -chdir=infra/terraform/environments/dev validate
```

Gerar plano local, depois de configurar credenciais AWS e variáveis obrigatórias:

```powershell
$env:TF_VAR_eks_cluster_role_name = "LabRole"
$env:TF_VAR_eks_node_role_name = "LabRole"
terraform -chdir=infra/terraform/environments/dev plan
```

<a id="operação-e-documentação"></a>

## 🧭 Operação e documentação

- [Visão geral, arquitetura e ordem das esteiras](https://github.com/oficina-mecanica-soat/oficina-mecanica-api#deploy-aws).
- [Configuração, primeira aplicação e recuperação após Reset](https://github.com/oficina-mecanica-soat/oficina-mecanica-api/blob/develop/docs/deploy/deploy-aws.md).
- [Collection consolidada e ambientes Local/Development](https://github.com/oficina-mecanica-soat/oficina-mecanica-api/blob/develop/docs/evidencias/postman.md).

Todo provisionamento, atualização e destroy na AWS ocorre pelas esteiras oficiais. O controle é `infra/terraform/environments/dev/terraform-action.env`; destroy exige alteração dedicada e verificação dos consumidores. `AWS_DEPLOY_ENABLED` autoriza a janela real, e `AUTO_PR_ENABLED` controla somente a abertura de promoções. Alterar uma Variable não dispara o CD.

Um ambiente disponível pode ser testado sem destroy. Sem estado compatível, alguns owners exigem primeiro uma recuperação por destroy dedicado com inventário vazio comprovado. Não apague recursos ou caches para contornar o bloqueio; consulte o guia antes de iniciar uma conta ou retomar um laboratório.

Fluxo Git: branch de trabalho → PR para `develop` → `release` → `main`. O CD físico ocorre em development; release e production registram promoções lógicas. PRs e merges permanecem sujeitos aos checks e à revisão. Mudanças somente em README/docs não exigem deploy físico pelos detectores atuais.
