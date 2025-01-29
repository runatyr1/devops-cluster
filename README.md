# Kubernetes Security and Infrastructure Demo

A comprehensive demonstration project showcasing various DevOps, Infrastructure, and Site Reliability Engineering (SRE) capabilities, with a strong focus on Kubernetes security and infrastructure automation.

## 🎯 Overview

This project implements a production-ready Kubernetes environment with emphasis on security, infrastructure as code, and automated deployment. It serves as a practical demonstration of various cloud-native technologies and best practices.

## 🏗️ Infrastructure Features

- **Infrastructure as Code**
  - Terraform configuration for Hetzner Cloud
  - Supporting configurations for AWS (in development)
  - Automated node provisioning and configuration

- **Configuration Management**
  - Ansible-based automated cluster bootstrapping
  - Modular playbook structure for maintainability
  - Secure configuration defaults

## 🛡️ Security Features

### Container Security
- Custom secure base images with distroless implementations
- Multi-stage builds for minimal attack surface
- Container vulnerability scanning with Trivy
- Custom Caddy secure implementation

### Kubernetes Security
- Pod Security Admission Controls
- Network Policies for pod-to-pod communication
- gVisor (runsc) runtime isolation
- Custom seccomp profiles
- Restricted Service Account configurations
- CIS Kubernetes Benchmark compliance checking

### System Security
- Kernel hardening configurations
- UFW firewall rules
- Secure SSH configurations
- Unnecessary kernel module blacklisting
- System service hardening

## 🔧 Core Components

### Networking
- Cilium for CNI with WireGuard encryption
- MetalLB for bare metal load balancing
- NGINX Ingress Controller
- Automated TLS with cert-manager

### Monitoring & Metrics
- Metrics Server deployment
- Resource usage tracking
- Performance monitoring capabilities

## 🚀 Demo Scenarios

1. **Security Hardening**
   - Pod security policy enforcement
   - Network isolation demonstration
   - Runtime isolation with gVisor
   - Security benchmark testing

2. **Access Control**
   - Service Account token binding
   - RBAC configurations
   - Network policy enforcement

3. **TLS/Ingress**
   - Let's Encrypt integration
   - Self-signed certificate handling
   - Secure ingress configurations

## 📂 Project Structure

```
.
├── infrastructure/         # IaC configurations
│   ├── aws/              # AWS specific configs
│   ├── hetzner/          # Hetzner specific configs
│   └── keys/             # SSH keys (gitignored)
├── kubernetes/           # K8s configurations
│   ├── base/            # Base configurations
│   │   ├── helm/        # Helm charts
│   │   ├── manifests/   # K8s manifests
│   │   └── templates/   # Configuration templates
│   ├── dockerfiles/     # Custom container builds
│   └── overlays/        # Environment overlays
├── scripts/             # Utility scripts
└── vault/              # HashiCorp Vault configs
```

## 🛠️ Prerequisites

- Terraform >= 1.0
- Ansible >= 2.9
- kubectl >= 1.29
- Helm >= 3.0
- Docker >= 20.10


## 🚦 Getting Started

### Prerequisites Configuration

1. **SSH Key Generation**
   ```bash
   # Generate SSH key pair for Hetzner nodes
   ssh-keygen -t ed25519 -f infrastructure/keys/hetzner-k8s -C "k8s-cluster"
   ```

2. **Required Files Setup**
   ```bash
   # Copy and configure template files
   cp infrastructure/hetzner/inventory.yml.template infrastructure/hetzner/inventory.yml
   cp infrastructure/hetzner/secret_vars.yml.template infrastructure/hetzner/secret_vars.yml
   ```

3. **Create terraform.tfvars**
   ```bash
   # Create and edit terraform.tfvars in infrastructure/hetzner/
   cat > infrastructure/hetzner/terraform.tfvars << EOF
   hcloud_token = "your-hetzner-api-token"
   ssh_key_public = "infrastructure/keys/hetzner-k8s.pub"
   ssh_key_private = "infrastructure/keys/hetzner-k8s"
   cluster_name = "k8s-demo"
   EOF
   ```

### Deployment Steps

1. **Initialize Terraform**
   ```bash
   cd infrastructure/hetzner
   terraform init
   ```

2. **Deploy Infrastructure**
   ```bash
   # Review the planned changes
   terraform plan
   
   # Apply the changes
   terraform apply
   ```

3. **Configure Ansible Inventory**
   ```bash
   # Update inventory.yml with the new server IP
   # The IP will be shown in terraform output
   vim inventory.yml
   ```

4. **Configure Secret Variables**
   ```bash
   # Edit secret_vars.yml with required credentials
   # Minimum required variables:
   # - ansible_become_pass
   # - docker_registry_password (if using private registry)
   vim secret_vars.yml
   ```

5. **Bootstrap Kubernetes Cluster**
   ```bash
   # Run the bootstrap playbook
   ansible-playbook -i inventory.yml bootstrap.yml
   ```

6. **Deploy Kubernetes Resources**
   ```bash
   # Deploy all Kubernetes resources
   ansible-playbook -i inventory.yml k8s-resources.yml
   ```

### Verification

1. **Check Cluster Status**
   ```bash
   # Configure kubeconfig
   export KUBECONFIG=/etc/kubernetes/admin.conf
   
   # Verify nodes
   kubectl get nodes
   
   # Verify core components
   kubectl get pods -A
   ```

2. **Test Security Features**
   ```bash
   # Run security benchmark
   kubectl apply -f kubernetes/base/manifests/sec-cis-linux-and-kube-bench.yaml
   
   # Check network policies
   ./scripts/tests/demo-network-policies.sh
   ```

### Important Notes

- All sensitive files are gitignored for security:
  - SSH keys in `infrastructure/keys/`
  - `terraform.tfvars` containing API tokens
  - `secret_vars.yml` containing passwords
  - `inventory.yml` containing server details
  - All `*.tfstate` files
- The project expects a Hetzner Cloud account with API access
- Ensure all prerequisites (Terraform, Ansible, kubectl, etc.) are installed
- Keep all generated credentials and keys secure
- Regular backups of state files are recommended

## 📝 Notes

- This project is designed for demonstration and learning purposes
- Contains various security-focused implementations and best practices
- Can be used as a reference for production deployments
- Actively maintained with regular updates

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.