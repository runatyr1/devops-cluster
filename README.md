# Keys and secrets
infrastructure/keys/*
*.pem
*.key
*.crt

# Terraform
infrastructure/*/.terraform/
infrastructure/*/.terraform.lock.hcl
infrastructure/*/*.tfstate
infrastructure/*/*.tfstate.*
infrastructure/*/*.tfvars
*.tfstate
*.tfstate.backup
**/inventory.yml*

# Kubernetes
kubernetes/**/*secret*.yaml
kubernetes/**/*.secret
kubeconfig
.kube/
**/kubeconfig*

# Local environment
.env
.envrc
*.log

# IDE and system files
.vscode/
.idea/
*.swp
.DS_Store

# Scripts output
scripts/**/*.out
scripts/**/*.log

# Hetzner
**/hcloud.yaml
**/hcloud.json

# Temporary files
*.tmp
*.temp
*~

# Vault
vault/**/local.hcl
vault/**/*.secret
.vault-token
**/secret_vars.yml*
*.vault

# Monitoring / logging
monitoring/**/*.secret
monitoring/**/credentials.*
**/*.log

# Additional security
security/**/*key*
security/**/*credential*
security/**/*secret*

# Environment specific configs
config/environments/**/*.local
config/environments/**/*.secret

# Keep these empty directories with .gitkeep
!infrastructure/keys/.gitkeep