# PM-TP Infrastructure

Infrastructure components for the PM-TP project management platform.

## Prerequisites

### Cluster Configuration

For OpenSearch to deploy successfully, the Kubernetes cluster must allow the `vm.max_map_count` sysctl. In Rancher RKE2 clusters, add the following to the cluster configuration YAML:

```yaml
spec:
  rkeConfig:
    machineGlobalConfig:
      kubelet:
        allowedUnsafeSysctls:
          - vm.max_map_count
```

This enables the OpenSearch Helm chart's `sysctlInitContainer` to automatically set the required kernel parameter.

## Components

This repository manages the deployment of:

- **TiDB**: Distributed SQL database
- **Valkey**: Redis-compatible cache
- **MinIO**: S3-compatible object storage
- **NATS**: Cloud-native messaging system
- **OpenSearch**: Search and analytics engine
- **Harbor**: Container registry with TLS
- **Traefik**: Ingress controller with middleware support
- **Keycloak**: Identity and access management
- **Prometheus**: Monitoring and alerting
- **Grafana**: Metrics visualization

## Harbor Configuration

Harbor is deployed with TLS encryption using Let's Encrypt certificates.

### Login Credentials (Demo)

For demo purposes, use these credentials to access Harbor:

- **URL**: https://harbor.rancher-poc.1.todevopssandbox.com
- **Username**: `admin`
- **Password**: `Harbor12345`

### Manual Ingress Fix

If Harbor is not accessible with a trusted certificate, apply the correct ingress configuration:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pm-tp-infra-harbor-ingress
  namespace: pm-tp-staging
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  rules:
  - host: harbor.rancher-poc.1.todevopssandbox.com
    http:
      paths:
      - backend:
          service:
            name: pm-tp-infra-harbor-core
            port:
              number: 80
        path: /api/
        pathType: Prefix
      - backend:
          service:
            name: pm-tp-infra-harbor-core
            port:
              number: 80
        path: /service/
        pathType: Prefix
      - backend:
          service:
            name: pm-tp-infra-harbor-core
            port:
              number: 80
        path: /v2/
        pathType: Prefix
      - backend:
          service:
            name: pm-tp-infra-harbor-core
            port:
              number: 80
        path: /chartrepo/
        pathType: Prefix
      - backend:
          service:
            name: pm-tp-infra-harbor-core
            port:
              number: 80
        path: /c/
        pathType: Prefix
      - backend:
          service:
            name: pm-tp-infra-harbor-portal
            port:
              number: 80
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - harbor.rancher-poc.1.todevopssandbox.com
    secretName: harbor-tls-secret
EOF
```

**Note**: This fix may need to be reapplied after Fleet redeploys the infrastructure.

### Internal Configuration Fix

After deployment, Harbor's internal configuration may still use default hostnames. If Harbor generates incorrect URLs or redirects, update the external endpoint:

```bash
# Update Harbor's external endpoint configuration
kubectl patch configmap pm-tp-infra-harbor-core -n pm-tp-staging --type merge -p '{"data":{"EXT_ENDPOINT":"https://harbor.rancher-poc.1.todevopssandbox.com"}}'

# Restart Harbor core to apply changes
    delete pod -l app=harbor,component=core -n pm-tp-staging
```

## Traefik Configuration

Traefik is deployed as an ingress controller with middleware support for advanced routing capabilities.

### Features Enabled

- **Kubernetes CRD Provider**: Enables Traefik IngressRoute and Middleware resources
- **Cross-namespace support**: Allows routing across namespaces
- **Let's Encrypt integration**: Automatic TLS certificate management
- **LoadBalancer service**: Exposes Traefik externally
- **Middleware CRDs**: Enables advanced routing features (auth, rate limiting, etc.)

### Deployment Order

Traefik is deployed as a separate Fleet bundle that runs **before** the main infrastructure. This ensures:

1. Traefik CRDs are available for the main infrastructure components
2. The pm-tp application can use Traefik middlewares immediately
3. No dependency conflicts during deployment

### Namespace

Traefik is deployed in the `traefik-system` namespace.

### Configuration Files

- `deployments/fleet/traefik-fleet.yaml`: Fleet bundle definition
- `deployments/{env}/traefik-values.yaml`: Environment-specific values

## Creating a New Cluster

Follow these steps to launch a new Kubernetes cluster ready for PM-TP infrastructure deployment:

### 1. Access Rancher UI

Log into your Rancher management interface.

### 2. Create New Cluster

1. Navigate to **Cluster Management** > **Clusters**
2. Click **Create**
3. Select **RKE2/K3s** as the cluster type
4. Choose your cloud provider or infrastructure (e.g., Amazon EC2, vSphere)

### 3. Configure Cluster Basics

1. Enter a **Cluster Name** (e.g., `pm-tp-prod`)
2. Select **Kubernetes Version** (recommended: latest stable, e.g., v1.33.5+rke2r1)
3. Choose **Cloud Provider** credentials if applicable

### 4. Configure Advanced Options

1. In the **Cluster Configuration** section, click **Edit as YAML**
2. Add the required `machineGlobalConfig` for OpenSearch:

```yaml
spec:
  kubernetesVersion: v1.33.5+rke2r1
  rkeConfig:
    machineGlobalConfig:
      kubelet:
        allowedUnsafeSysctls:
          - vm.max_map_count
```

3. Configure additional settings as needed (networking, security, etc.)

### 5. Add Node Pools

1. Define **Machine Pools** for your cluster nodes
2. Ensure nodes have sufficient resources:
   - **CPU**: At least 2 cores per node
   - **Memory**: At least 4GB per node
   - **Storage**: At least 50GB per node
3. For production workloads, use multiple node pools for different components

### 6. Create the Cluster

1. Review your configuration
2. Click **Create**
3. Wait for the cluster to provision (this may take 10-20 minutes)

### 7. Verify Cluster Readiness

Once the cluster is active:

```bash
# Set kubectl context to new cluster
kubectl config use-context <cluster-name>

# Verify nodes are ready
kubectl get nodes

# Check cluster health
kubectl get pods -n kube-system
```

### 8. Label the Cluster

Label your cluster for Fleet deployment:

```bash
kubectl label cluster <cluster-name> env=<environment>
```

Replace `<environment>` with `dev`, `staging`, or `prod`.

## Deployment

Infrastructure is deployed using Fleet GitOps from this repository.

### Quick Start

```bash
# Label your cluster
kubectl label cluster local env=dev

# Apply Fleet GitRepo
kubectl apply -f fleet-gitrepo.yaml

# Monitor deployment
kubectl get bundles -n fleet-default
```

### Environments

- **Development**: Minimal resources, single replicas
- **Staging**: Moderate resources, HA configuration
- **Production**: Full HA, optimized resources

## Documentation

See [docs/](docs/) for detailed setup guides for each component.

## Related Repositories

- [pm-tp](https://github.com/TransPerfectCloudDevOps/pm-tp): Main application
