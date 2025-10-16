#!/bin/bash
# Setup infrastructure on Kubernetes cluster

set -e

ENVIRONMENT="${1:-dev}"
NAMESPACE="pm-tp-$ENVIRONMENT"

echo "🚀 Setting up pm-tp infrastructure"
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo ""

# Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add pingcap https://charts.pingcap.org/
helm repo add valkey https://charts.valkey.io
helm repo add minio https://charts.min.io/
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo add keycloak https://charts.keycloak.org
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "✅ Helm repositories added"

# Update dependencies
echo "📥 Updating chart dependencies..."
cd charts/pm-tp-infrastructure
helm dependency update
cd ../..

echo "✅ Dependencies updated"

# Create namespace
echo "📁 Creating namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Install chart
echo "🎯 Installing infrastructure chart..."
helm upgrade --install pm-tp-infra \
  ./charts/pm-tp-infrastructure \
  --namespace "$NAMESPACE" \
  --values "deployments/$ENVIRONMENT/values.yaml" \
  --wait \
  --timeout 15m

echo ""
echo "✅ Infrastructure deployed successfully!"
echo ""
echo "Check status:"
echo "  kubectl get all -n $NAMESPACE"
