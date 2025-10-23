#!/bin/bash

# Manual Keycloak Deployment for Rancher Cluster
# Based on: https://www.keycloak.org/getting-started/getting-started-kube
# Adapted for Rancher instead of minikube

set -e

echo "🚀 Deploying Keycloak manually to Rancher cluster..."

# Create namespace
echo "📁 Creating keycloak namespace..."
kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -

# Download Keycloak YAML files
echo "📥 Downloading Keycloak YAML files..."
mkdir -p yaml
curl -s https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/refs/heads/main/kubernetes/keycloak.yaml -o yaml/keycloak.yaml

# Modify the service to be LoadBalancer type for external access
echo "🔧 Modifying service to LoadBalancer type..."
sed -i.bak 's/type: ClusterIP/type: LoadBalancer/' yaml/keycloak.yaml

# Deploy Keycloak StatefulSet and Service
echo "⚙️  Deploying Keycloak StatefulSet and Service..."
kubectl apply -f yaml/keycloak.yaml -n keycloak

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak pod to be ready..."
kubectl wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=300s

# Get the external IP/load balancer IP
echo "🔍 Getting external IP address for DNS setup..."
echo "Waiting for LoadBalancer IP..."

# Try to get LoadBalancer IP (may take a few minutes)
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  LB_IP=$(kubectl get svc keycloak -n keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  if [ ! -z "$LB_IP" ]; then
    echo "✅ LoadBalancer IP found: $LB_IP"
    echo "📋 Use this IP to create a DNS A record in Route53:"
    echo "   keycloak.yourdomain.com -> $LB_IP"
    break
  fi

  echo "⏳ Waiting for LoadBalancer IP... ($ELAPSED/$TIMEOUT seconds)"
  sleep 10
  ELAPSED=$((ELAPSED + 10))
done

if [ -z "$LB_IP" ]; then
  echo "⚠️  LoadBalancer IP not found within timeout. Check manually:"
  echo "kubectl get svc keycloak -n keycloak"
  echo "kubectl describe svc keycloak -n keycloak"
fi

echo ""
echo "🎉 Keycloak deployment complete!"
echo ""
echo "🔑 Access Keycloak:"
echo "   Internal: kubectl port-forward svc/keycloak 8080:8080 -n keycloak"
echo "   External: http://$LB_IP (after LoadBalancer IP is assigned)"
echo ""
echo "👤 Default admin credentials:"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "📝 Next steps:"
echo "1. Wait for LoadBalancer IP to be assigned"
echo "2. Set up DNS A record: keycloak.yourdomain.com -> $LB_IP"
echo "3. Access Keycloak and change default password"
echo "4. Configure realms and clients for your application"