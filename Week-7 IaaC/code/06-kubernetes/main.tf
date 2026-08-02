# ---------------------------------------------------------------------------
# Lab 06 - Kubernetes objects, managed by Terraform instead of kubectl apply.
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "app" {
  metadata {
    name = "${var.student_name}-app"
    labels = {
      "managed-by" = "terraform"
    }
  }
}

# Config as a first-class Terraform resource: change a value here and
# `terraform plan` shows you exactly which pods will be affected.
resource "kubernetes_config_map" "app" {
  metadata {
    name      = "podinfo-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    PODINFO_UI_COLOR   = "#fb923c"
    PODINFO_UI_MESSAGE = "Deployed by Terraform, built by ${var.student_name}"
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = "podinfo"
    namespace = kubernetes_namespace.app.metadata[0].name
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
        # Changing the ConfigMap changes this annotation, which forces a
        # rolling restart. Without it, pods keep the stale config forever.
        annotations = {
          "config-hash" = sha256(jsonencode(kubernetes_config_map.app.data))
        }
      }

      spec {
        container {
          name  = "podinfo"
          image = var.app_image

          port {
            container_port = 9898
            name           = "http"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.app.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              memory = "256Mi" # no CPU limit on purpose - CPU limits cause throttling
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 9898
            }
            initial_delay_seconds = 5
          }

          readiness_probe {
            http_get {
              path = "/readyz"
              port = 9898
            }
            initial_delay_seconds = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "podinfo"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = { app = "podinfo" }

    port {
      port        = 80
      target_port = 9898
    }

    # ClusterIP + port-forward keeps this lab free and firewall-friendly.
    # See labs/06 for the LoadBalancer bonus.
    type = "ClusterIP"
  }
}
