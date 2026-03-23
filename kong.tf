locals {
  kong_lambda_config = {
    function_name = "${var.lambda_function_name}"
    aws_region    = var.region

    forward_request_body    = true
    forward_request_headers = true
    forward_request_method  = true
    skip_large_bodies       = false
    is_proxy_integration    = true
    base64_encode_body      = false
  }
}

resource "kubernetes_namespace" "kong" {
  metadata {
    name = "kong"
  }

  depends_on = [module.eks]
}

resource "helm_release" "kong" {
  name       = "kong"
  repository = "https://charts.konghq.com"
  chart      = "kong"
  namespace  = kubernetes_namespace.kong.metadata[0].name
  version    = "2.38.0"

  values = [
    <<-YAML
    proxy:
      type: LoadBalancer
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: nlb
    admin:
      enabled: true
      type: ClusterIP
    env:
      database: "off"
    ingressController:
      enabled: true
      installCRDs: false
    YAML
  ]

  depends_on = [module.eks]
}

# ── /auth → Lambda ────────────────────────────────────────────────────────────

resource "kubernetes_service" "auth_lambda_dummy" {
  metadata {
    name      = "auth-lambda-dummy"
    namespace = kubernetes_namespace.kong.metadata[0].name
  }

  spec {
    port {
      port        = 80
      target_port = 80
    }
    selector = {
      app = "non-existent"
    }
  }

  depends_on = [helm_release.kong]
}

resource "kubernetes_manifest" "kong_plugin_auth_lambda" {
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongPlugin"
    metadata = {
      name      = "auth-lambda-plugin"
      namespace = kubernetes_namespace.kong.metadata[0].name
    }
    plugin = "aws-lambda"
    config = local.kong_lambda_config
  }

  depends_on = [helm_release.kong]
}

resource "kubernetes_manifest" "kong_ingress_auth" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "auth-lambda-ingress"
      namespace = kubernetes_namespace.kong.metadata[0].name
      annotations = {
        "konghq.com/plugins"    = "auth-lambda-plugin"
        "konghq.com/strip-path" = "false"
      }
    }
    spec = {
      ingressClassName = "kong"
      rules = [{
        http = {
          paths = [{
            path     = "/auth"
            pathType = "Prefix"
            backend = {
              service = {
                name = "auth-lambda-dummy"
                port = { number = 80 }
              }
            }
          }]
        }
      }]
    }
  }

  depends_on = [
    helm_release.kong,
    kubernetes_manifest.kong_plugin_auth_lambda,
    kubernetes_service.auth_lambda_dummy,
  ]
}

# ── /api/* → NestJS ───────────────────────────────────────────────────────────

resource "kubernetes_service" "autoflow_app" {
  metadata {
    name      = "autoflow-app"
    namespace = kubernetes_namespace.kong.metadata[0].name
  }

  spec {
    type          = "ExternalName"
    external_name = "autoflow.autoflow.svc.cluster.local"
    port {
      port        = 80
      target_port = 80
    }
  }

  depends_on = [helm_release.kong]
}

resource "kubernetes_manifest" "kong_ingress_api" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "api-ingress"
      namespace = kubernetes_namespace.kong.metadata[0].name
      annotations = {
        "konghq.com/strip-path"  = "false"
        "konghq.com/protocols"   = "http,https"
        "konghq.com/host-header" = "autoflow.autoflow.svc.cluster.local"
      }
    }
    spec = {
      ingressClassName = "kong"
      rules = [{
        http = {
          paths = [{
            path     = "/api"
            pathType = "Prefix"
            backend = {
              service = {
                name = "autoflow-app"
                port = { number = 80 }
              }
            }
          }]
        }
      }]
    }
  }

  depends_on = [
    helm_release.kong,
    kubernetes_service.autoflow_app,
  ]
}
