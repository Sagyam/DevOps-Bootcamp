output "namespace" {
  value = kubernetes_namespace_v1.lab.metadata[0].name
}

output "access_hint" {
  value = "Run: minikube service podinfo -n tf-lab --url"
}
