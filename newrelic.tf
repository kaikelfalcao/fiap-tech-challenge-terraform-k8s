resource "kubernetes_namespace" "newrelic" {
  metadata {
    name = "newrelic"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "newrelic" {
  name       = "newrelic-bundle"
  repository = "https://helm-charts.newrelic.com"
  chart      = "nri-bundle"
  namespace  = kubernetes_namespace.newrelic.metadata[0].name
  version    = "5.0.88"

  wait          = true
  wait_for_jobs = true
  timeout       = 300

  values = [
    <<-YAML
    global:
      licenseKey: "${var.newrelic_license_key}"
      cluster: "${module.eks.cluster_name}"
      lowDataMode: true

    newrelic-infrastructure:
      enabled: true
      privileged: true
      verboseLog: false
      kubelet:
        resources:
          limits:
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 150Mi
      ksm:
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 50m
            memory: 100Mi
      controlPlane:
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 50m
            memory: 100Mi

    kube-state-metrics:
      enabled: true

    nri-kube-events:
      enabled: true

    nri-prometheus:
      enabled: true
      config:
        scrape_enabled_label: "prometheus.io/scrape"

    newrelic-logging:
      enabled: true
      fluentBit:
        criEnabled: true
        resources:
          limits:
            cpu: 500m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi

    nri-metadata-injection:
      enabled: true

    pixie-chart:
      enabled: false

    newrelic-k8s-metrics-adapter:
      enabled: false
    YAML
  ]

  depends_on = [module.eks]
}
