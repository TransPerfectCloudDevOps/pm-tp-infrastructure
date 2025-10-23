#!/bin/bash

# Manual Keycloak Deployment for Rancher Cluster
# Based on: https://www.keycloak.org/getting-started/getting-started-kube
# Adapted for Rancher with Ingress and Let's Encrypt

set -e

echo "🚀 Deploying Keycloak manually to Rancher cluster..."

# Create namespace
echo "📁 Creating keycloak namespace..."
kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -

# Download Keycloak YAML files
echo "📥 Downloading Keycloak YAML files..."
mkdir -p keycloak-manual
curl -s https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/refs/heads/main/kubernetes/keycloak.yaml -o keycloak-manual/keycloak.yaml

# Modify the YAML: set keycloak service to ClusterIP and add management port
echo "🔧 Modifying YAML for ClusterIP service and health port..."
sed -i.bak '0,/type: ClusterIP/ s/type: ClusterIP/type: ClusterIP/' keycloak-manual/keycloak.yaml  # Ensure it's ClusterIP
# Add management port to StatefulSet
sed -i.bak '/ports:/a\            - name: management\n              containerPort: 9000' keycloak-manual/keycloak.yaml

# Install cert-manager if not present
echo "🔐 Installing cert-manager for Let's Encrypt..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Deploy Keycloak StatefulSet and Service
echo "⚙️  Deploying Keycloak StatefulSet and Service..."
kubectl apply -f keycloak-manual/keycloak.yaml -n keycloak

# Deploy cert-manager resources
echo "📜 Deploying Let's Encrypt ClusterIssuer and Certificate..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@todevopssandbox.com  # Update with your email
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: keycloak-tls
  namespace: keycloak
spec:
  secretName: keycloak-tls-secret
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
  - keycloak.rancher-poc.1.todevopssandbox.com
EOF

# Deploy Ingress
echo "🌐 Deploying Ingress for external access..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: keycloak
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - keycloak.rancher-poc.1.todevopssandbox.com
    secretName: keycloak-tls-secret
  rules:
  - host: keycloak.rancher-poc.1.todevopssandbox.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 8080
EOF

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak pods to be ready..."
kubectl wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=300s

# Wait for certificate
echo "⏳ Waiting for certificate to be ready..."
kubectl wait --for=condition=ready certificate/keycloak-tls -n keycloak --timeout=600s

echo "✅ Keycloak deployment complete!"
echo "🔗 Access URL: https://keycloak.rancher-poc.1.todevopssandbox.com"
echo "👤 Admin credentials: admin / admin"
echo "📋 DNS: Ensure A record points to a node external IP (e.g., 34.221.220.254)"
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