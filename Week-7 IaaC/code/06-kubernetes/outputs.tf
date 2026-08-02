output "namespace" {
  value = kubernetes_namespace.app.metadata[0].name
}

output "port_forward_command" {
  value = "kubectl -n ${kubernetes_namespace.app.metadata[0].name} port-forward svc/podinfo 8080:80"
}

output "then_open" {
  value = "http://localhost:8080"
}
