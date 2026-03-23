#!/bin/bash

# Script para instalar New Relic Bundle no EKS
# Uso: ./install-newrelic.sh [LICENSE_KEY] [CLUSTER_NAME] [ENVIRONMENT]

set -e

# Variáveis padrão
LICENSE_KEY="${1:-586e901e3d286e9c15862a4b363cdf3bFFFFNRAL}"
CLUSTER_NAME="${2:-tech-challenge}"
ENVIRONMENT="${3:-dev}"
KSM_IMAGE_VERSION="v2.13.0"
NAMESPACE="newrelic"

echo "=========================================="
echo "New Relic Bundle Installation"
echo "=========================================="
echo "License Key: ${LICENSE_KEY:0:20}..."
echo "Cluster Name: $CLUSTER_NAME"
echo "Environment: $ENVIRONMENT"
echo "KSM Version: $KSM_IMAGE_VERSION"
echo "Namespace: $NAMESPACE"
echo "=========================================="
echo ""

# Adicionar repositório Helm
echo "Adding New Relic Helm repository..."
helm repo add newrelic https://helm-charts.newrelic.com
helm repo update

# Criar namespace se não existir
echo "Creating namespace '$NAMESPACE'..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Instalar New Relic Bundle
echo "Installing New Relic Bundle..."
helm upgrade --install newrelic-bundle newrelic/nri-bundle \
  --set global.licenseKey=$LICENSE_KEY \
  --set global.cluster=$CLUSTER_NAME \
  --namespace=$NAMESPACE \
  --set global.lowDataMode=true \
  --set kube-state-metrics.image.tag=$KSM_IMAGE_VERSION \
  --set kube-state-metrics.enabled=true \
  --set kubeEvents.enabled=true \
  --set newrelic-prometheus-agent.enabled=true \
  --set newrelic-prometheus-agent.lowDataMode=true \
  --set newrelic-prometheus-agent.config.kubernetes.integrations_filter.enabled=false \
  --set nr-ebpf-agent.enabled=true \
  --set k8s-agents-operator.enabled=true \
  --set logging.enabled=true \
  --set newrelic-logging.lowDataMode=true

echo ""
echo "=========================================="
echo "Installation completed!"
echo "=========================================="
echo ""
echo "Verifying New Relic pods..."
kubectl get pods -n $NAMESPACE

