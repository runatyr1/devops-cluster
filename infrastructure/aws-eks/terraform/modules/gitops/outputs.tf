output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_endpoint" {
  description = "ArgoCD server endpoint"
  value       = "Use kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

output "applicationset_name" {
 description = "Name of the ApplicationSet"
 value       = yamldecode(kubectl_manifest.apps_applicationset.yaml_body).metadata.name
}