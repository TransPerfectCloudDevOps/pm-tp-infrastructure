#!/bin/bash

# Manual Keycloak Deployment Script
# Deploys Keycloak to its own namespace with cross-namespace DB access

set -e

echo "🚀 Deploying Keycloak manually to dedicated namespace..."

# Create namespace
echo "📁 Creating keycloak namespace..."
kubectl apply -f keycloak/namespace.yaml

# Add Bitnami Helm repo if not already added
echo "📦 Adding Bitnami Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami || echo "Repository already exists"

# Update Helm repos
echo "🔄 Updating Helm repositories..."
helm repo update

# Deploy Keycloak
echo "⚙️  Deploying Keycloak with Helm..."
helm upgrade --install keycloak bitnami/keycloak \
  --namespace keycloak \
  --values keycloak/values.yaml \
  --version 21.1.2 \
  --wait

echo "✅ Keycloak deployment complete!"
echo ""
echo "🔍 Check deployment status:"
echo "kubectl get pods -n keycloak"
echo ""
echo "📋 View Keycloak logs:"
echo "kubectl logs -n keycloak deployment/keycloak"
echo ""
echo "🌐 Access Keycloak (if ingress enabled):"
echo "kubectl get ingress -n keycloak"
echo ""
echo "🔌 Port forward for local access:"
echo "kubectl port-forward -n keycloak svc/keycloak 8080:80"