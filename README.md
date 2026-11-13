# ☸️ Oficina Mecânica Infra Kubernetes

Repositório da esteira Kubernetes da Fase 3 do Tech Challenge.

## 🎯 Objetivo

Provisionar e operar a base Kubernetes da solução da Oficina Mecânica em AWS, mantendo o mesmo padrão de CI/CD usado na API e nas demais esteiras de infraestrutura.

## 📌 Responsabilidades

- Criar o cluster EKS de `development`.
- Criar o Managed Node Group.
- Criar os repositórios ECR das imagens da API e do serviço de Execução.
- Consumir os outputs da VPC publicados no SSM Parameter Store.
- Publicar outputs de Kubernetes e ECR no SSM para as próximas esteiras.
- Controlar `apply` e `destroy` por workflow com validações reais na AWS.
- Instalar e validar Datadog Agent e Cluster Agent no EKS.

## 🔀 Fluxo Git

```text
branch de trabalho -> PR develop -> deploy development -> PR release -> deploy homologation -> PR main -> deploy production
```

Branches protegidas esperadas:

- `develop`
- `release`
- `release/*`
- `main`

As branches protegidas usam dois rulesets ativos:

- **🔒 Proteção Git Flow, sem bypass:** exige PR, conversas resolvidas, checks `🔀 01 · Validar fluxo de branches` e `🚦 03 · Quality gate` aprovados; bloqueia push direto, force push e deleção. A lista de bypass fica vazia, inclusive para admins e maintainers.
- **👥 Aprovação de PR:** exige uma aprovação, descarta aprovações antigas e exige revisão por alguém diferente do último autor do push. Somente esta regra permite bypass via PR para `geoscabio`, `sousagabriel14`, maintainers e admins.

O bypass dispensa a revisão de outra pessoa, nunca o fluxo ou os checks. PRs podem ser abertos de qualquer origem, mas o merge exige `branch de trabalho -> develop -> release -> main`. Hotfix permanece pós-entrega, sem exceção habilitada.

O ruleset de fluxo usa `strict_required_status_checks_policy=false` para não exigir promoção inversa entre branches; checks continuam obrigatórios e conflitos reais precisam ser resolvidos. O proprietário ainda pode alterar as configurações administrativas: o bloqueio depende dos rulesets ativos e da integridade dos workflows de validação.

Repetir este padrão em cada novo repositório. A configuração detalhada está no [guia de GitHub Actions da API](https://github.com/geoscabio/oficina-mecanica-api/blob/develop/docs/deploy/github-actions.md#-proteções-obrigatórias-recomendadas).

## 🔁 Workflows

| Workflow | Responsabilidade |
| --- | --- |
| `🧪 CI Development` | Validar PR para `develop`, Git Flow e Terraform quando houver mudança deployable. |
| `🔎 CI Release` | Validar PR para `release` ou `release/**`, Git Flow e Terraform quando houver mudança deployable. |
| `🛡️ CI Production` | Validar PR para `main`, Git Flow e Terraform quando houver mudança deployable. |
| `🚀 CD Development` | Detectar mudança deployable em `develop`, chamar o deploy real e abrir PR para `release` quando habilitado. |
| `☁️ AWS Deploy` | Resolver `apply`/`destroy`, gerar plano, aplicar Terraform, validar AWS e publicar state em cache. |
| `🔀 CD Release` | Registrar deploy lógico em `homologation` e abrir PR para `main` quando habilitado. |
| `🏁 CD Production` | Registrar deploy lógico em `production`. |

O desenho dos workflows segue a API. A diferença fica apenas no conteúdo técnico de cada job: aqui a validação e o deploy são de Terraform/EKS/ECR. O título de execução do `🔀 CD Release` é `🔀 Registrar deploy em release`; produção só é registrada depois do merge em `main`.

## 🌐 Dependência da VPC

Antes de aplicar Kubernetes, a VPC precisa estar pronta e publicar os parâmetros abaixo:

| Parâmetro SSM | Uso |
| --- | --- |
| `/oficina-mecanica/development/status/vpc` | Deve estar com valor `ready`. |
| `/oficina-mecanica/development/vpc/vpc_id` | VPC usada pelo EKS. |
| `/oficina-mecanica/development/vpc/private_subnet_ids` | Subnets privadas usadas pelo cluster e pelo node group. |

## 📤 Outputs publicados

Depois do apply, esta esteira publica:

| Parâmetro SSM | Uso |
| --- | --- |
| `/oficina-mecanica/development/status/kubernetes` | Marca Kubernetes como pronto para dependentes. |
| `/oficina-mecanica/development/kubernetes/cluster_name` | Nome do cluster EKS. |
| `/oficina-mecanica/development/kubernetes/cluster_endpoint` | Endpoint do cluster EKS. |
| `/oficina-mecanica/development/kubernetes/cluster_security_group_id` | Security group principal do cluster. |
| `/oficina-mecanica/development/kubernetes/node_group_name` | Nome do Managed Node Group. |
| `/oficina-mecanica/development/kubernetes/ecr_repository_name` | Nome do ECR da API. |
| `/oficina-mecanica/development/kubernetes/ecr_repository_url` | URL do ECR da API. |
| `/oficina-mecanica/development/kubernetes/execucao_ecr_repository_name` | Nome do ECR do serviço de Execução: `oficina-mecanica-execucao`. |
| `/oficina-mecanica/development/kubernetes/execucao_ecr_repository_url` | URL do ECR do serviço de Execução. |

### ECR do Execução — contrato da Fase 4

Conforme ADR-0023/25 e F4-04, o ECR continua sob ownership desta infraestrutura. O módulo `ecr_execucao` reutiliza `modules/ecr`, com as mesmas políticas da API: tags imutáveis, varredura no push e remoção de imagens no destroy acadêmico. O nome padrão é `oficina-mecanica-execucao`, configurado por `execucao_ecr_repository_name`. Não altera o endereço Terraform `module.ecr` nem os contratos existentes da API.

Os dois novos parâmetros são `String`, sem dados sensíveis, e usam `kubernetes_ssm_prefix`. Os outputs Terraform têm os mesmos nomes dos sufixos SSM. O status `ready` depende também da criação do novo registry e de seus contratos. Após apply autorizado, a esteira compara a URL no ECR, os outputs Terraform e os dois parâmetros SSM; no destroy, confirma ausência do registry identificado no state e dos parâmetros. Falhas de permissão/autenticação continuam bloqueando a operação.

Este PR prepara infraestrutura; não publica imagem, não cria workload, DynamoDB ou SQS e não conecta consumidores. O PR seguinte do Execução consumirá esses contratos, eliminando a configuração paralela por `ECR_REPOSITORY_NAME`.

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

## 🧭 Controle apply/destroy

O deploy real é controlado por:

```text
infra/terraform/environments/dev/terraform-action.env
```

Para subir ou atualizar Kubernetes:

```env
TERRAFORM_ACTION=apply
```

Para destruir Kubernetes:

```env
TERRAFORM_ACTION=destroy
```

Regra de segurança: `destroy` só é aceito quando `terraform-action.env` muda no próprio PR/merge. Isso evita destruir recursos em execuções futuras por acidente.

Com `AWS_DEPLOY_ENABLED=false` (ou ausente), o CD não chama Terraform nem Datadog. Mudança implantável bloqueada não abre promoção para release como se tivesse sido aplicada; mudanças apenas documentais mantêm a promoção existente. O workflow reutilizável AWS também exige habilitação explícita. `terraform-action.env` permanece inalterado; habilitar o controle não substitui o PR dedicado exigido para destroy. Avisar Gabriel para criar o laboratório e atualizar os environments antes da futura janela de validação.

O deploy do Datadog ocorre automaticamente após mudanças relevantes e um `apply` bem-sucedido. O `workflow_dispatch` permanece como contingência manual. Em `destroy`, a esteira não tenta instalar Datadog.

Para validar o runtime, confirme os nodes do EKS e os rollouts do Agent e Cluster Agent no namespace `datadog`, além dos parâmetros SSM publicados por esta esteira.

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

## 🗓️ Ordem da Fase 3

Esta esteira deve rodar depois da VPC e antes do deploy da API no EKS.

```text
infra-vpc -> infra-kubernetes -> api -> infra-api-gateway
```

RDS e Kubernetes podem evoluir em paralelo depois que a VPC estiver disponível.

Documentação central e arquitetura completa: [README da Oficina Mecânica API](https://github.com/geoscabio/oficina-mecanica-api).

### Reconciliação de destroy após reset do laboratório

O destroy restaura o cache Terraform existente e usa uma configuração temporária sem data sources de contratos SSM. O state original não é editado nem descartado: o provider confirma os recursos ausentes durante o plano de destruição. Somente o plano salvo, sem criação ou atualização, pode ser aplicado. Ao terminar, a esteira verifica que o state não contém recursos gerenciados antes de persistir o cache final. Falhas de autenticação, permissão ou rede bloqueiam a operação.

Na API, vínculos Kubernetes só podem ser retirados por blocos declarativos removed com destroy=false após ResourceNotFoundException confirmar que o EKS registrado no state não existe. Com EKS existente, permanece a configuração normal de destroy. Não há uso de state rm, import ou mv.

O retorno isolado de terraform-action.env para apply ainda é reconhecido como mudança de infraestrutura pelo detector de CD; não faça esse retorno enquanto não existir separação segura entre rearmar e provisionar. Preserve destroy após a reconciliação e só autorize nova subida em tarefa própria.

#### State isolado por conta AWS

As chaves de cache incluem o ID da conta retornado pela autenticação AWS, antes do ambiente e da execução. A restauração só pesquisa esse escopo, sem fallback para chaves históricas sem conta. Os caches anteriores permanecem preservados como histórico do laboratório encerrado 058264466885, inclusive quando contêm referências que a conta atual não consegue consultar. AccessDenied não é convertido em ausência.

Sem cache no escopo atual, a esteira bloqueia apply. Um destroy dedicado só pode iniciar state novo depois de consultas read-only confirmarem que não existem recursos ou contratos do projeto na conta atual. Recursos internos do laboratório são preservados. Depois disso, o plano exclusivo de destroy e a validação de state vazio produzem o cache usado pelas próximas execuções da mesma conta. Em laboratório com recursos existentes e cache ausente, é necessário recuperar o state correto; o bootstrap não libera provisionamento automático.

## Validação deste incremento

Validação local com Terraform 1.15.8: formatação, inicialização sem backend e validação aprovadas; quatro testes Node dos guardrails aprovados. O Terraform global 1.17.0 não atende à restrição do repositório; foi usado o executável 1.15.8 já disponível, sem alterar essa restrição. O CI repete as verificações antes do merge. Não há prova de criação/remoção real sem a janela AWS autorizada. O próximo apply criará um ECR e dois parâmetros SSM adicionais e atualizará o status compartilhado; a mesma esteira continuará gerenciando seu ciclo de vida.

## Preparação da subida — F4-04

### Recuperação do acesso IMDSv2 acadêmico

O detector do CD considera deployáveis tanto `infra/terraform/*` quanto os workflows `aws-deploy.yml` e `cd-development.yml`, pois mudanças na execução operacional precisam ser aplicadas. Mudanças exclusivas de CI/README não acionam AWS; Datadog mantém seu detector especializado. A habilitação `AWS_DEPLOY_ENABLED` continua obrigatória e independente da detecção.

Na validação remota do Execução, o node apresentou `HttpTokens=required` e hop limit `1`; o SDK no Pod falhou ao obter token IMDSv2. Gabriel aprovou propor hop limit `2`, preservando tokens obrigatórios e reconhecendo acesso possível por outros Pods do mesmo node, conforme complemento da ADR-0025 na API. Não oferece isolamento IAM por aplicação.

Após apply e persistência do state, a esteira existente configura somente as instâncias atuais dos Auto Scaling Groups retornados pelo node group gerenciado. Exige grupo ACTIVE, `LabRole` da conta autenticada, instâncias running e tag do cluster correspondente. Aplica endpoint habilitado, tokens obrigatórios e hop limit `2`, confirmando o estado aplicado; consulta ou alteração negada interrompe a esteira. Destroy não executa essa etapa. Não altera IAM/trust, não lê credenciais IMDS e não copia secrets do runner para Pods.

A configuração operacional é por instância, fora do plano Terraform, e não muda o launch template gerenciado pelo EKS. Não cria template próprio nem substitui o node group existente. Uma instância substituída posteriormente pode voltar ao padrão: reexecutar a esteira Kubernetes antes de validar o runtime remoto e conferir novamente os valores reais. Este é um limite explícito da exceção acadêmica, não uma configuração durável de novos nodes.

O PR não executa a alteração AWS: `AWS_DEPLOY_ENABLED=false` permanece até a janela autorizada, após merge de Gabriel. O apply parcial do Execução mantém seu state; a correção não recria tabela ou filas e ainda exige nova validação de identidade e acesso DynamoDB/SQS pelo Pod. Healthcheck não comprova essas permissões.

Após a validação real da VPC em 11/11/2026, o retorno do controle a `apply` prepara a próxima etapa da plataforma. `AWS_DEPLOY_ENABLED=false` permanece no repositório; o merge não provisiona EKS/ECR nem instala Datadog. A execução exige janela autorizada e credenciais/dependências reconferidas.

A revisão corrigiu no job de aplicação a restauração do cache para ocorrer antes da validação do state, preparação de destroy e terraform init, seguindo o mesmo padrão da VPC/Execução. A chave continua isolada por conta; o cache e o state não são editados/apagados. O teste inline do CI confere a ordem nos dois jobs. Não acrescenta arquivo ou pasta de scripts.

O futuro apply utiliza a configuração existente: EKS, managed node group nas subnets privadas, ECRs da API e Execução, NLB interno com seus recursos de ingresso e contratos SSM. O CD existente chama em seguida o workflow especializado de Datadog, com Agent e Cluster Agent. Não cria nova role IAM ou workload da aplicação, não provisiona RDS/Gateway e não altera topologia, nomes, versões ou regras dos módulos.

A VPC deve continuar `ready` e publicar os contratos esperados. As roles existentes do laboratório e a chave Datadog configurada precisam funcionar na execução real; testes locais não comprovam IAM, conectividade, admissão do tracer ou ingestão de telemetria. O status de infraestrutura não prova a Saga ou os serviços. Gabriel faz o merge e autoriza separadamente o provisionamento dessa etapa.

## Bloqueio de operação AWS — AUD-001

`AWS_DEPLOY_ENABLED` deve existir no nível do repositório e permanecer `false` enquanto o laboratório estiver offline. Ausente, vazio ou diferente de `true` bloqueia a operação. O caller exige a habilitação antes de chamar o deploy; o workflow reutilizável repete a conferência no Environment e aceita operação física somente em `develop`/`development`, antes de resolver a ação e acessar AWS. Um override no Environment não substitui a habilitação do caller.

A entrada manual e a chamada automática do Datadog usam a mesma trava: o job é pulado sem habilitação ou fora de `develop`, e a primeira etapa confere novamente a flag antes de configurar credenciais ou instalar/atualizar o Agent. O deploy Terraform mantém sua trava existente, agora com conferência de ref/ambiente.

Habilitar a variável não autoriza operação por si só: ainda exige janela combinada com Gabriel, laboratório/credenciais atuais, dependências e os guardrails existentes de plano salvo/state e destroy dedicado. Não altera JWT, rotas, recursos, contratos SSM ou `terraform-action.env`. Merge de código não implanta.

O CI executa a barreira real com flags ausentes/inválidas, branches/tags e ambientes indevidos, além do caso positivo, sem credenciais ou comandos AWS. Testes e validações ficam inline nos workflows existentes, sem novas pastas de scripts. Nesta rodada, integrar somente em `develop`; Gabriel realiza o merge. Não promover release/main ou abrir nova janela de laboratório para este ajuste.
