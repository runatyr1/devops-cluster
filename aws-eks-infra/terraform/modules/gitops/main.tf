terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
  }
}

locals {
  argocd_namespace = "argocd"
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.environment
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = local.argocd_namespace
    labels = local.common_labels
  }
}



# Configure AWS Secrets Manager to store ArgoCD secret
resource "aws_secretsmanager_secret" "argocd_secret" {
  name = "argocd/dex-server-key-${var.environment}-${replace(var.aws_region, "-", "")}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "argocd_secret" {
  secret_id     = aws_secretsmanager_secret.argocd_secret.id
  secret_string = base64encode(random_password.argocd_secret.result)
}

resource "random_password" "argocd_secret" {
  length  = 32
  special = true
}

# Retrieve secret in Helm config
data "aws_secretsmanager_secret_version" "argocd_secret" {
  secret_id = aws_secretsmanager_secret.argocd_secret.id

  depends_on = [aws_secretsmanager_secret_version.argocd_secret]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      global = {
        nodeSelector = var.node_selector
      }
      dex = {
        enabled = true
        config = {
          secretKey = data.aws_secretsmanager_secret_version.argocd_secret.secret_string
        }
      }
      configs = {
        repositories = {
          git-repo = {
            url = var.git_repo_url
            type = "git"
          }
        }
      }
    server = {
      name = "server"
      extraArgs = ["--insecure"]
      service = {
        type = "LoadBalancer"
      }
      ingress = {
        enabled = true
      }
      resources = {
        limits = {
          cpu    = "300m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "150m"
          memory = "128Mi"
        }
      }
    }
    controller = {
      name = "application-controller"
      resources = {
        limits = {
          cpu    = "500m"     # Critical component, needs more CPU
          memory = "512Mi"    # Needs memory for app state management
        }
        requests = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }
    }
    applicationSet = {
      name = "applicationset-controller"
      resources = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    }
    repoServer = {
      name = "repo-server"
      resources = {
        limits = {
          cpu    = "300m"     # Important for git operations
          memory = "256Mi"
        }
        requests = {
          cpu    = "150m"
          memory = "128Mi"
        }
      }
    }
    redis = {
      name = "redis"
      resources = {
        limits = {
          cpu    = "200m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "64Mi"
        }
      }
    }
    notifications = {
      name = "notifications-controller"
      resources = {
        limits = {
          cpu    = "200m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "64Mi"
        }
      }
    }
   })
  ]

  depends_on = [kubernetes_namespace.argocd]
}


resource "kubectl_manifest" "apps_applicationset" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind = "ApplicationSet"
    metadata = {
      name = "${var.environment}-apps"
      namespace = local.argocd_namespace
    }
    spec = {
      generators = [{
        git = {
          repoURL = var.git_repo_url
          revision = var.git_revision
          directories = [{
            path = "aws-eks-kubernetes/base/*"
          }, {
            path = "aws-eks-kubernetes/overlays/*"
          }]
        }
      }]
      template = {
        metadata = {
          name = "{{path.basename}}"
          namespace = local.argocd_namespace
        }
        spec = {
          project = "default"
          source = {
            repoURL = var.git_repo_url
            targetRevision = var.git_revision
            path = "{{path}}"
          }
          destination = {
            server = "https://kubernetes.default.svc"
            namespace = "{{path.basename}}"
          }
          syncPolicy = {
            automated = {
              prune = true
              selfHeal = true
            }
          }
        }
      }
    }
  })
   depends_on = [
   helm_release.argocd,
   kubernetes_namespace.argocd
 ]
}




resource "kubectl_manifest" "chart_applicationset" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "${var.environment}-charts"
      namespace = local.argocd_namespace
    }
    spec = {
      generators = [{
        git = {
          repoURL  = var.git_repo_url
          revision = var.git_revision
          directories = [
            {
              path = "aws-eks-kubernetes/charts/*"
            },
            {
              path    = "aws-eks-kubernetes/charts/umbrella-chart"  # Explicitly exclude umbrella
              exclude = true
            }
          ]
        }
      }]
      template = {
        metadata = {
          name      = "{{path.basename}}"  # e.g., "iot-simulator"
          namespace = local.argocd_namespace
        }
        spec = {
          project = "default"
          source = {
            repoURL        = var.git_repo_url
            targetRevision = var.git_revision
            path           = "aws-eks-kubernetes/charts/{{path.basename}}"  # Subchart directory
            helm = {
              # Key change: Reference values from the umbrella chart
              valueFiles = [
                "../umbrella-chart/values-${var.aws_region}.yaml"  # Relative path to umbrella
              ]
            }
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{path.basename}}"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = ["CreateNamespace=true"]
          }
        }
      }
    }
  })
}