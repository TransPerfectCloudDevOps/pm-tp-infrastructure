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

## MinIO Configuration

MinIO is deployed as a distributed object storage cluster, providing S3-compatible storage.

### Connection Information

**Staging Environment:**
- **API Endpoint**: `http://pm-tp-infra-minio.pm-tp-staging.svc.cluster.local:9000`
- **Console UI**: `http://pm-tp-infra-minio-console.pm-tp-staging.svc.cluster.local:9001`
- **Root User**: `admin`
- **Root Password**: `changeme123`
- **Version**: RELEASE.2024-01-11T07-46-16Z
- **Mode**: Distributed (4 nodes)
- **Total Storage**: 200Gi (50Gi per node)
- **Pre-created Buckets**: `pm-tp-files`

### Accessing MinIO

**Via Port-Forward (Console UI):**
```bash
# Forward the console port
kubectl port-forward -n pm-tp-staging svc/pm-tp-infra-minio-console 9001:9001

# Access the web console at http://localhost:9001
# Login with: admin / changeme123
```

**Via Port-Forward (API):**
```bash
# Forward the API port
kubectl port-forward -n pm-tp-staging svc/pm-tp-infra-minio 9000:9000

# API accessible at http://localhost:9000
```

### Using MinIO from Applications

**Using MinIO Client (mc):**
```bash
# From within a pod, configure the client
mc alias set myminio http://pm-tp-infra-minio:9000 admin changeme123

# List buckets
mc ls myminio

# Create a bucket
mc mb myminio/my-bucket

# Upload a file
mc cp myfile.txt myminio/my-bucket/

# Download a file
mc cp myminio/my-bucket/myfile.txt ./

# List objects in bucket
mc ls myminio/pm-tp-files
```

**Connection URLs:**
```
# S3-compatible endpoint
s3://pm-tp-infra-minio:9000

# HTTP endpoint
http://pm-tp-infra-minio:9000
http://pm-tp-infra-minio.pm-tp-staging.svc.cluster.local:9000
```

**From application pods (Python with boto3):**
```python
import boto3
from botocore.client import Config

# Create S3 client
s3_client = boto3.client(
    's3',
    endpoint_url='http://pm-tp-infra-minio:9000',
    aws_access_key_id='admin',
    aws_secret_access_key='changeme123',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)

# List buckets
response = s3_client.list_buckets()
print([bucket['Name'] for bucket in response['Buckets']])

# Upload a file
s3_client.upload_file('localfile.txt', 'pm-tp-files', 'remotefile.txt')

# Download a file
s3_client.download_file('pm-tp-files', 'remotefile.txt', 'downloaded.txt')

# List objects
response = s3_client.list_objects_v2(Bucket='pm-tp-files')
for obj in response.get('Contents', []):
    print(obj['Key'])
```

**From application pods (Go with minio-go):**
```go
import (
    "github.com/minio/minio-go/v7"
    "github.com/minio/minio-go/v7/pkg/credentials"
)

// Initialize MinIO client
minioClient, err := minio.New("pm-tp-infra-minio:9000", &minio.Options{
    Creds:  credentials.NewStaticV4("admin", "changeme123", ""),
    Secure: false,
})

// Upload a file
_, err = minioClient.FPutObject(context.Background(), "pm-tp-files",
    "myfile.txt", "/path/to/file.txt", minio.PutObjectOptions{})

// Download a file
err = minioClient.FGetObject(context.Background(), "pm-tp-files",
    "myfile.txt", "/path/to/download.txt", minio.GetObjectOptions{})
```

**From application pods (environment variables):**
```yaml
env:
  - name: S3_ENDPOINT
    value: http://pm-tp-infra-minio:9000
  - name: S3_ACCESS_KEY
    value: admin
  - name: S3_SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: minio-credentials
        key: secretkey
  - name: S3_BUCKET
    value: pm-tp-files
  - name: S3_REGION
    value: us-east-1
```

### Features

- **S3 Compatible**: Works with AWS S3 SDKs and tools
- **Distributed Mode**: 4-node cluster for high availability
- **Web Console**: User-friendly UI for bucket management
- **Persistent Storage**: 50Gi per node using Longhorn (200Gi total)
- **Erasure Coding**: Data protection and redundancy
- **Versioning**: Object versioning support
- **Pre-created Bucket**: `pm-tp-files` ready to use

### Monitoring

**Check MinIO status:**
```bash
# View pod logs
kubectl logs -n pm-tp-staging pm-tp-infra-minio-0

# Check all pods status
kubectl get pods -n pm-tp-staging -l app=minio

# Check storage usage
kubectl exec -n pm-tp-staging pm-tp-infra-minio-0 -- df -h /export
```

**Using MinIO Client for admin tasks:**
```bash
# Get into a pod
kubectl exec -it -n pm-tp-staging pm-tp-infra-minio-0 -- sh

# Configure admin alias
mc alias set admin http://localhost:9000 admin changeme123

# Get server info
mc admin info admin

# Check service status
mc admin service status admin
```

**Important Note**: The default credentials (`admin:changeme123`) should be changed in production environments.

## MySQL Configuration

MySQL is deployed as a StatefulSet using the official MySQL 8.4 image with persistent storage.

### Connection Information

**Staging Environment:**
- **Host**: `pm-tp-infra-mysql.pm-tp-staging.svc.cluster.local`
- **Port**: `3306`
- **Root Password**: `changeme123`
- **Database**: `pmtp`
- **User**: `pmtp`
- **Password**: `changeme123`
- **Storage**: 20Gi persistent volume (Longhorn)
- **Version**: MySQL 8.4.7

### Connecting from Applications

**Using mysql CLI:**
```bash
# Connect as pmtp user
mysql -h pm-tp-infra-mysql -u pmtp -pchangeme123 pmtp

# Connect as root
mysql -h pm-tp-infra-mysql -u root -pchangeme123

# Test connection
mysql -h pm-tp-infra-mysql -u pmtp -pchangeme123 -e "SELECT VERSION();"
```

**Connection string formats:**
```
mysql://pmtp:changeme123@pm-tp-infra-mysql:3306/pmtp
jdbc:mysql://pm-tp-infra-mysql:3306/pmtp?user=pmtp&password=changeme123
```

**From application pods:**
```yaml
# Environment variables for your application
env:
  - name: DB_HOST
    value: pm-tp-infra-mysql
  - name: DB_PORT
    value: "3306"
  - name: DB_NAME
    value: pmtp
  - name: DB_USER
    value: pmtp
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: mysql-credentials
        key: password
```

### Features

- **Persistent Storage**: 20Gi volume using Longhorn
- **StatefulSet**: Ensures stable network identity
- **Resource Limits**: CPU (250m-1000m) and Memory (512Mi-2Gi)
- **Official MySQL Image**: Using mysql:8.4

## Valkey Configuration

Valkey is deployed as a Redis-compatible in-memory data store with persistent storage.

### Connection Information

**Staging Environment:**
- **Host**: `pm-tp-infra-valkey.pm-tp-staging.svc.cluster.local`
- **Port**: `6379`
- **Password**: `changeme123`
- **Storage**: 10Gi persistent volume (Longhorn)

### Connecting from Applications

**Using valkey-cli:**
```bash
# From within the cluster
valkey-cli -h pm-tp-infra-valkey -p 6379 -a changeme123

# Test connection
valkey-cli -h pm-tp-infra-valkey -p 6379 -a changeme123 ping
```

**Connection string formats:**
```
redis://default:changeme123@pm-tp-infra-valkey:6379
valkey://default:changeme123@pm-tp-infra-valkey:6379
```

**From application pods:**
```yaml
# Environment variables for your application
env:
  - name: REDIS_HOST
    value: pm-tp-infra-valkey
  - name: REDIS_PORT
    value: "6379"
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: valkey-credentials
        key: password
```

### Features

- **Persistent Storage**: Data survives pod restarts using Longhorn PVC
- **Authentication**: ACL-based authentication enabled
- **Resource Limits**: CPU (100m-500m) and Memory (256Mi-512Mi)
- **Health Checks**: Automatic liveness and startup probes

## NATS Configuration

NATS is deployed as a cloud-native messaging system for pub/sub and request/reply patterns.

### Connection Information

**Staging Environment:**
- **Host**: `pm-tp-infra-nats.pm-tp-staging.svc.cluster.local`
- **Port**: `4222` (Client connections)
- **Monitoring Port**: `8222` (HTTP monitoring endpoint)
- **Version**: NATS 2.9.22
- **Server Name**: `pm-tp-infra-nats-0`

**Note**: JetStream persistence is configured but not currently enabled. The deployment is running in simple messaging mode.

### Connecting from Applications

**Using nats CLI (from nats-box pod):**
```bash
# Access the NATS box pod
kubectl exec -n pm-tp-staging deployment/pm-tp-infra-nats-box -it -- sh

# Publish a message
nats pub test.subject "Hello NATS"

# Subscribe to a subject
nats sub test.subject

# Request-reply pattern
nats reply help.desk "I can help!"
nats request help.desk "I need help"
```

**Connection URLs:**
```
nats://pm-tp-infra-nats:4222
nats://pm-tp-infra-nats.pm-tp-staging.svc.cluster.local:4222
```

**From application pods (example in Go):**
```go
import "github.com/nats-io/nats.go"

// Connect to NATS
nc, err := nats.Connect("nats://pm-tp-infra-nats:4222")
if err != nil {
    log.Fatal(err)
}
defer nc.Close()

// Publish
nc.Publish("subject", []byte("message"))

// Subscribe
nc.Subscribe("subject", func(m *nats.Msg) {
    fmt.Printf("Received: %s\n", string(m.Data))
})
```

**From application pods (environment variables):**
```yaml
env:
  - name: NATS_URL
    value: nats://pm-tp-infra-nats:4222
  - name: NATS_HOST
    value: pm-tp-infra-nats
  - name: NATS_PORT
    value: "4222"
```

### Features

- **Pub/Sub Messaging**: Lightweight publish-subscribe pattern
- **Request/Reply**: Synchronous request-response messaging
- **Monitoring**: HTTP monitoring endpoint on port 8222
- **NATS Box**: Included utility pod for testing and debugging
- **StatefulSet**: Stable network identity for clustering

### Monitoring

Check NATS server health:
```bash
# Get server info via monitoring endpoint
kubectl port-forward -n pm-tp-staging pm-tp-infra-nats-0 8222:8222
curl http://localhost:8222/varz
```

## OpenSearch Configuration

OpenSearch is deployed as a 3-node cluster for search and analytics workloads.

### Connection Information

**Staging Environment:**
- **Host**: `opensearch-cluster-master.pm-tp-staging.svc.cluster.local`
- **Port**: `9200` (HTTP REST API)
- **Transport Port**: `9300` (Inter-node communication)
- **Protocol**: HTTPS (TLS enabled)
- **Username**: `admin`
- **Password**: `admin`
- **Version**: OpenSearch 2.0.0
- **Cluster Name**: `opensearch-cluster`
- **Nodes**: 3 master-eligible data nodes
- **Storage**: 8Gi per node (24Gi total)
- **Cluster Status**: Green

### Connecting from Applications

**Using curl:**
```bash
# Get cluster info
curl -k -u admin:admin https://opensearch-cluster-master:9200/

# Check cluster health
curl -k -u admin:admin https://opensearch-cluster-master:9200/_cluster/health?pretty

# List indices
curl -k -u admin:admin https://opensearch-cluster-master:9200/_cat/indices?v

# Create an index
curl -k -u admin:admin -X PUT https://opensearch-cluster-master:9200/my-index

# Index a document
curl -k -u admin:admin -X POST https://opensearch-cluster-master:9200/my-index/_doc \
  -H 'Content-Type: application/json' \
  -d '{"title": "Hello OpenSearch", "timestamp": "2025-10-28"}'

# Search
curl -k -u admin:admin https://opensearch-cluster-master:9200/my-index/_search?q=Hello
```

**Connection URLs:**
```
https://admin:admin@opensearch-cluster-master:9200
https://opensearch-cluster-master.pm-tp-staging.svc.cluster.local:9200
```

**From application pods (Python example):**
```python
from opensearchpy import OpenSearch

# Create client
client = OpenSearch(
    hosts=[{'host': 'opensearch-cluster-master', 'port': 9200}],
    http_auth=('admin', 'admin'),
    use_ssl=True,
    verify_certs=False,
    ssl_show_warn=False
)

# Index a document
response = client.index(
    index='my-index',
    body={'title': 'Hello', 'timestamp': '2025-10-28'}
)

# Search
results = client.search(
    index='my-index',
    body={'query': {'match': {'title': 'Hello'}}}
)
```

**From application pods (environment variables):**
```yaml
env:
  - name: OPENSEARCH_HOST
    value: opensearch-cluster-master
  - name: OPENSEARCH_PORT
    value: "9200"
  - name: OPENSEARCH_USERNAME
    value: admin
  - name: OPENSEARCH_PASSWORD
    valueFrom:
      secretKeyRef:
        name: opensearch-credentials
        key: password
  - name: OPENSEARCH_URL
    value: https://opensearch-cluster-master:9200
```

### Features

- **High Availability**: 3-node cluster with automatic failover
- **Full-Text Search**: Powerful search and analytics capabilities
- **RESTful API**: Easy integration with HTTP clients
- **Security**: TLS encryption and authentication enabled
- **Persistent Storage**: 8Gi per node using Longhorn
- **Resource Limits**: CPU (1000m) and Memory (2Gi) per node

### Monitoring

**Check cluster status:**
```bash
# Port-forward to access locally
kubectl port-forward -n pm-tp-staging opensearch-cluster-master-0 9200:9200

# View cluster health
curl -k -u admin:admin https://localhost:9200/_cluster/health?pretty

# View node stats
curl -k -u admin:admin https://localhost:9200/_cat/nodes

# View indices
curl -k -u admin:admin https://localhost:9200/_cat/indices?v
```

**Important Note**: The default credentials (`admin:admin`) should be changed in production environments. Refer to OpenSearch Security documentation for proper authentication setup.

## Traefik Configuration

Traefik is deployed as an ingress controller for HTTP/HTTPS routing with automatic TLS certificate management.

### Connection Information

**Staging Environment:**
- **Service Name**: `pm-tp-infra-traefik.pm-tp-staging.svc.cluster.local`
- **Type**: LoadBalancer
- **HTTP Port**: `80` (NodePort: 31407) - Auto-redirects to HTTPS
- **HTTPS Port**: `443` (NodePort: 32324)
- **Dashboard Port**: `9000` (Internal only)
- **Version**: Traefik 2.10.6
- **Cluster IP**: 10.43.253.188

### Accessing Traefik

**Via NodePort (when LoadBalancer IP is pending):**
```bash
# Get node IP
kubectl get nodes -o wide

# Access via NodePort (replace <NODE_IP> with actual node IP)
curl http://<NODE_IP>:31407
curl -k https://<NODE_IP>:32324
```

**Via Port-Forward:**
```bash
# Forward HTTP port
kubectl port-forward -n pm-tp-staging deployment/pm-tp-infra-traefik 8080:8000

# Forward HTTPS port
kubectl port-forward -n pm-tp-infra deployment/pm-tp-infra-traefik 8443:8443

# Access locally
curl http://localhost:8080
curl -k https://localhost:8443
```

### Using Traefik for Application Routing

**Standard Kubernetes Ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: pm-tp-staging
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
```

**Traefik IngressRoute (CRD):**
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app-route
  namespace: pm-tp-staging
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`myapp.example.com`)
    kind: Rule
    services:
    - name: my-app
      port: 80
  tls:
    certResolver: le
```

**Traefik Middleware Example:**
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: my-auth
  namespace: pm-tp-staging
spec:
  basicAuth:
    secret: auth-secret

---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app-with-auth
  namespace: pm-tp-staging
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`myapp.example.com`)
    kind: Rule
    middlewares:
    - name: my-auth
    services:
    - name: my-app
      port: 80
  tls:
    certResolver: le
```

### Features

- **Automatic HTTPS Redirect**: HTTP traffic automatically redirects to HTTPS
- **Let's Encrypt Integration**: Automatic TLS certificate provisioning
- **Kubernetes CRD Support**: IngressRoute and Middleware custom resources
- **Cross-Namespace Routing**: Can route to services in different namespaces
- **Dynamic Configuration**: Watches Kubernetes resources for automatic updates
- **Middleware Support**: Authentication, rate limiting, headers, and more

### Monitoring

**Check Traefik logs:**
```bash
kubectl logs -n pm-tp-staging deployment/pm-tp-infra-traefik -f
```

**View Traefik dashboard (if enabled):**
```bash
# Port-forward the dashboard
kubectl port-forward -n pm-tp-staging deployment/pm-tp-infra-traefik 9000:9000

# Access at http://localhost:9000/dashboard/
```

**List all IngressRoutes:**
```bash
kubectl get ingressroute -A
```

**List all Middlewares:**
```bash
kubectl get middleware -A
```

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
