# Manual Keycloak Deployment for Rancher

This directory contains a manual Keycloak deployment setup for Rancher clusters, based on the official Keycloak getting started guide but adapted for production use.

## What's Included

- `deploy.sh`: Main deployment script
- `yaml/`: Directory containing downloaded and modified YAML files

## Deployment Process

1. **Run the deployment script:**
   ```bash
   ./keycloak-manual/deploy.sh
   ```

2. **What the script does:**
   - Creates the `keycloak` namespace
   - Downloads the official Keycloak YAML
   - Modifies the service to use LoadBalancer type (for external access)
   - Deploys Keycloak StatefulSet and Service
   - Waits for the pod to be ready
   - Retrieves the LoadBalancer external IP

3. **DNS Setup:**
   - The script will output the LoadBalancer IP
   - Create an A record in Route53: `keycloak.yourdomain.com -> [LB_IP]`

## Access Keycloak

- **Internal access:** `kubectl port-forward svc/keycloak 8080:8080 -n keycloak`
- **External access:** `http://[LB_IP]` or `https://keycloak.yourdomain.com` (after DNS)

## Default Credentials

- Username: `admin`
- Password: `admin`

⚠️ **Important:** Change the default password immediately after first login!

## Cleanup

To remove Keycloak:
```bash
kubectl delete namespace keycloak
```

## Differences from Official Guide

- Uses LoadBalancer service instead of Ingress (simpler for Rancher)
- Downloads YAML files locally for better control
- Includes external IP retrieval for DNS setup
- Adapted for Rancher clusters instead of minikube