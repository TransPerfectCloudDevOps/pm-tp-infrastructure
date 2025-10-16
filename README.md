# PM-TP Infrastructure

Infrastructure components for the PM-TP project management platform.

## Components

This repository manages the deployment of:

- **TiDB**: Distributed SQL database
- **Valkey**: Redis-compatible cache
- **MinIO**: S3-compatible object storage
- **NATS**: Cloud-native messaging system
- **OpenSearch**: Search and analytics engine
- **Keycloak**: Identity and access management
- **Prometheus**: Monitoring and alerting
- **Grafana**: Metrics visualization

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
