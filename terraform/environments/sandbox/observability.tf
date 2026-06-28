# 1. Namespace for Observability Stack
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# 2. Helm Release for Grafana Loki Stack (Loki + Promtail)
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "2.10.2"

  set {
    name  = "loki.persistence.enabled"
    value = "true"
  }

  set {
    name  = "loki.persistence.storageClassName"
    value = "gp2"
  }

  set {
    name  = "loki.persistence.size"
    value = "10Gi"
  }

  set {
    name  = "promtail.enabled"
    value = "true"
  }

  depends_on = [
    module.compute,
    kubernetes_namespace.monitoring
  ]
}

# 3. Helm Release for Kube Prometheus Stack (Prometheus + Grafana + Alertmanager)
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "61.3.0"

  values = [
    yamlencode({
      # Prometheus spec: Retention 7 days and PVC gp2 10Gi
      prometheus = {
        prometheusSpec = {
          retention = "7d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
        }
      }

      # Grafana spec: ClusterIP only, Loki datasource integration, default admin password
      grafana = {
        adminPassword = "admin"
        service = {
          type = "ClusterIP"
        }
        additionalDataSources = [
          {
            name      = "Loki"
            type      = "loki"
            access    = "proxy"
            url       = "http://loki.monitoring.svc.cluster.local:3100"
            version   = 1
          }
        ]
      }

      # Alertmanager spec: custom routing rules, inhibition rules, webhook targets
      alertmanager = {
        config = {
          global = {
            resolve_timeout = "5m"
          }
          route = {
            group_by        = ["alertname", "namespace", "service"]
            group_wait      = "30s"
            group_interval  = "5m"
            repeat_interval = "12h"
            receiver        = "slack-warning"
            routes = [
              {
                match = {
                  severity = "critical"
                }
                receiver = "critical-alerts"
              },
              {
                match = {
                  severity = "warning"
                }
                receiver = "slack-warning"
              }
            ]
          }
          inhibit_rules = [
            {
              source_match = {
                severity = "critical"
              }
              target_match = {
                severity = "warning"
              }
              equal = ["service", "namespace"]
            }
          ]
          receivers = [
            {
              name = "slack-warning"
              slack_configs = [
                {
                  channel = "#alerts-warning"
                  api_url = ""
                }
              ]
            },
            {
              name = "critical-alerts"
              slack_configs = [
                {
                  channel = "#alerts-critical"
                  api_url = ""
                }
              ]
              webhook_configs = [
                {
                  url           = module.lambda.ingest_api_endpoint
                  send_resolved = true
                }
              ]
            }
          ]
        }
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "5Gi"
                  }
                }
              }
            }
          }
        }
      }
    })
  ]

  depends_on = [
    module.compute,
    kubernetes_namespace.monitoring,
    helm_release.loki
  ]
}
