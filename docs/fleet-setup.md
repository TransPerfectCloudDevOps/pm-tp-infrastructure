# Fleet Setup Guide

## Overview
This repository is configured to work with Rancher Fleet for GitOps deployment of infrastructure components.

## Changes Made to Support Fleet

### 1. Chart Dependencies
All Helm chart dependencies are defined in `charts/pm-tp-infrastructure/Chart.yaml` with proper repository URLs:

- **TiDB Operator**: `https://charts.pingcap.org/`
- **Valkey**: `https://valkey.io/valkey-helm/`
- **MinIO**: `https://charts.min.io/`
- **NATS**: `https://nats-io.github.io/k8s/helm/charts/`
- **OpenSearch**: `https://opensearch-project.github.io/helm-charts/`
- **Keycloak**: `https://codecentric.github.io/helm-charts`
- **Prometheus**: `https://prometheus-community.github.io/helm-charts`
- **Grafana**: `https://grafana.github.io/helm-charts`

### 2. Chart.lock File
The `Chart.lock` file is committed to the repository so Fleet knows which exact versions of dependencies to download.

### 3. GitRepo Configuration
The `fleet-gitrepo.yaml` includes `helmRepoURLRegex: "https://.*"` which allows Fleet to download Helm charts from any HTTPS repository listed in Chart.lock.

## Deploying to Fleet

### Option 1: Using the GitRepo Resource
Apply the GitRepo resource to your Fleet management cluster:

```bash
kubectl apply -f fleet-gitrepo.yaml
```

### Option 2: Via Rancher UI
1. Navigate to **Continuous Delivery** in Rancher
2. Click **Git Repos** > **Add Repository**
3. Fill in:
   - **Name**: `pm-tp-infrastructure`
   - **Repository URL**: `https://github.com/TransPerfectCloudDevOps/pm-tp-infrastructure.git`
   - **Branch**: `main`
   - **Helm Repository URL Regex**: `https://.*`
4. Configure target clusters using labels

## Troubleshooting

### Error: "no cached repository for helm-manager found"
**Solution**: This error occurs when Fleet can't download chart dependencies. Ensure:
1. `Chart.lock` is committed to the repository
2. `helmRepoURLRegex: "https://.*"` is set in the GitRepo spec
3. The Fleet controller has internet access to download charts

### Error: "failed reading resources"
**Solution**: Verify the chart structure and that all dependencies are properly defined in `Chart.yaml`.

## Target Environments

The fleet bundle is configured for three environments:

- **dev**: Deploys to clusters with label `env: dev`
- **staging**: Deploys to clusters with label `env: staging`
- **prod**: Deploys to clusters with label `env: prod`

Each environment uses its corresponding values file from `deployments/*/values.yaml`.

## Manual Dependency Update

If you need to update chart dependencies:

```bash
# Add helm repos
./scripts/setup.sh

# Update dependencies
cd charts/pm-tp-infrastructure
helm dependency update

# Commit the updated Chart.lock
git add Chart.lock
git commit -m "Update chart dependencies"
git push
```

Fleet will automatically pick up the changes and redeploy.
