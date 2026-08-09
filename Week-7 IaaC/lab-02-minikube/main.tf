# ---------------------------------------------------------------------------
# A namespace, a ConfigMap, a Deployment, and a Service -- the same objects
# you have written as YAML, now expressed as Terraform resources.
# Compare mentally: kind: Deployment  <->  resource "kubernetes_deployment_v1"
# ---------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "lab" {
  metadata {
    name = "tf-lab"
    labels = {
      managed-by = "terraform"
    }
  }
}

resource "kubernetes_config_map_v1" "podinfo" {
  metadata {
    name      = "podinfo-config"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }
  data = {
    PODINFO_UI_COLOR   = "#0D9488" # teal
    PODINFO_UI_MESSAGE = "Provisioned by Terraform"
  }
}

resource "kubernetes_deployment_v1" "podinfo" {
  metadata {
    name      = "podinfo"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
    labels    = { app = "podinfo" }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = "podinfo" }
    }

    template {
      metadata {
        labels = { app = "podinfo" }
      }

      spec {
        container {
          name  = "podinfo"
          image = "stefanprodan/podinfo:${var.app_version}"

          port {
            container_port = 9898
            name           = "http"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.podinfo.metadata[0].name
            }
          }

          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "200m", memory = "128Mi" }
          }

          readiness_probe {
            http_get {
              path = "/readyz"
              port = 9898
            }
            initial_delay_seconds = 3
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "podinfo" {
  metadata {
    name      = "podinfo"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }

  spec {
    selector = { app = "podinfo" }
    type     = "NodePort"

    port {
      port        = 9898
      target_port = 9898
      node_port   = 30988
    }
  }
}
