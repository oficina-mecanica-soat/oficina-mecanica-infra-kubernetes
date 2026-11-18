aws_region = "us-east-1"

# AWS Academy: role names can change between lab sessions.
# Configure before terraform plan/apply:
# PowerShell:
# $env:TF_VAR_eks_cluster_role_name = "<LabRole-or-EKS-cluster-role>"
# $env:TF_VAR_eks_node_role_name = "<LabRole-or-EKS-node-role>"
# Bash:
# export TF_VAR_eks_cluster_role_name="<LabRole-or-EKS-cluster-role>"
# export TF_VAR_eks_node_role_name="<LabRole-or-EKS-node-role>"
# Dois nós acomodam os três serviços, observabilidade e atualizações graduais.
# Limite explícito de custo durante a validação integrada.
desired_size = 2
min_size     = 1
max_size     = 2
