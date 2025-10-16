# Infrastructure Components

## TiDB

Distributed SQL database compatible with MySQL protocol.

**Resources:**
- Development: 1 PD, 1 TiKV, 1 TiDB
- Staging: 3 PD, 3 TiKV, 2 TiDB
- Production: 5 PD, 5 TiKV, 3 TiDB

**Access:**
```bash
kubectl port-forward svc/tidb 4000:4000 -n pm-tp-dev
mysql -h 127.0.0.1 -P 4000 -u root
```

## Valkey (Redis)

High-performance in-memory cache.

**Access:**
```bash
kubectl port-forward svc/valkey-master 6379:6379 -n pm-tp-dev
redis-cli -h 127.0.0.1
```

## MinIO

S3-compatible object storage.

**Access:**
```bash
kubectl port-forward svc/minio 9000:9000 9001:9001 -n pm-tp-dev
# Console: http://localhost:9001
# API: http://localhost:9000
```

## NATS

Cloud-native messaging with JetStream.

**Access:**
```bash
kubectl port-forward svc/nats 4222:4222 -n pm-tp-dev
```

## OpenSearch

Search and analytics engine.

**Access:**
```bash
kubectl port-forward svc/opensearch 9200:9200 -n pm-tp-dev
curl http://localhost:9200
```

## Keycloak

Identity and access management.

**Access:**
```bash
kubectl port-forward svc/keycloak 8080:8080 -n pm-tp-dev
# Console: http://localhost:8080
```

## Prometheus

Metrics collection and alerting.

**Access:**
```bash
kubectl port-forward svc/prometheus-server 9090:80 -n pm-tp-dev
# UI: http://localhost:9090
```

## Grafana

Metrics visualization and dashboards.

**Access:**
```bash
kubectl port-forward svc/grafana 3000:80 -n pm-tp-dev
# UI: http://localhost:3000
# Default: admin/admin123
```
