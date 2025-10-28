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

- **MySQL**: Relational database (official MySQL 8.4)
- **Valkey**: Redis-compatible cache
- **MinIO**: S3-compatible object storage
- **NATS**: Cloud-native messaging system
- **OpenSearch**: Search and analytics engine
- **cert-manager**: Automatic TLS certificate management
- **Harbor**: Container registry with TLS
- **Keycloak**: Identity and access management
- **Prometheus**: Monitoring and alerting
- **Grafana**: Metrics visualization

**Note**: nginx ingress controller comes pre-installed with RKE2 and is used for all HTTP/HTTPS routing.

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

## cert-manager Configuration

cert-manager is deployed to automatically manage TLS certificates from Let's Encrypt for all ingress resources.

### Overview

**Staging Environment:**
- **Version**: ~1.16.0
- **Namespace**: Deployed with infrastructure in `pm-tp-staging`
- **ClusterIssuers**: `letsencrypt-staging` and `letsencrypt-prod`
- **Email**: erik.hanson@transperfect.com
- **Ingress Class**: nginx
- **ACME Challenge**: HTTP-01

### ClusterIssuers

cert-manager creates two ClusterIssuers automatically:

1. **letsencrypt-staging**: For testing (uses Let's Encrypt staging environment)
2. **letsencrypt-prod**: For production certificates (uses Let's Encrypt production environment)

### Using cert-manager with Ingress

**Basic Ingress with automatic TLS:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: pm-tp-staging
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
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
    secretName: myapp-tls  # cert-manager will create this secret
```

**Using staging issuer for testing:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress-test
  namespace: pm-tp-staging
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"  # Use staging for testing
spec:
  ingressClassName: nginx
  rules:
  - host: test.myapp.example.com
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
    - test.myapp.example.com
    secretName: myapp-test-tls
```

**Manual Certificate resource:**
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-cert
  namespace: pm-tp-staging
spec:
  secretName: my-app-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
  - www.myapp.example.com
```

### Monitoring Certificates

**Check certificate status:**
```bash
# List all certificates
kubectl get certificates -n pm-tp-staging

# Describe a specific certificate
kubectl describe certificate myapp-tls -n pm-tp-staging

# Check certificate ready status
kubectl get certificate myapp-tls -n pm-tp-staging -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

**Check certificate requests:**
```bash
# List certificate requests
kubectl get certificaterequest -n pm-tp-staging

# View certificate request details
kubectl describe certificaterequest myapp-tls-xyz -n pm-tp-staging
```

**Check ClusterIssuers:**
```bash
# List ClusterIssuers
kubectl get clusterissuer

# Check issuer status
kubectl describe clusterissuer letsencrypt-prod
```

**View cert-manager logs:**
```bash
# View controller logs
kubectl logs -n pm-tp-staging -l app.kubernetes.io/name=cert-manager -f

# View webhook logs
kubectl logs -n pm-tp-staging -l app.kubernetes.io/component=webhook -f
```

### Troubleshooting

**Certificate not being issued:**
1. Check the Certificate status: `kubectl describe certificate <name> -n <namespace>`
2. Check CertificateRequest: `kubectl get certificaterequest -n <namespace>`
3. Check cert-manager logs for errors
4. Ensure DNS points to the ingress controller
5. Verify HTTP-01 challenge can reach `/.well-known/acme-challenge/`

**Rate limiting from Let's Encrypt:**
- Use `letsencrypt-staging` issuer for testing
- Let's Encrypt has rate limits: 50 certificates per domain per week
- Staging environment has higher rate limits for testing

**Common issues:**
- DNS not pointing to ingress: Ensure A record points to ingress external IP
- Ingress class mismatch: Ensure `ingressClassName: nginx` is set
- Wrong issuer: Double-check the `cert-manager.io/cluster-issuer` annotation

### Features

- **Automatic Certificate Renewal**: Certificates auto-renew before expiration
- **HTTP-01 Challenge**: Uses nginx ingress for ACME challenges
- **Multi-domain Certificates**: Support for multiple domains in one certificate
- **ClusterIssuers**: Available to all namespaces in the cluster
- **Automatic Secret Creation**: TLS secrets created and managed automatically

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
