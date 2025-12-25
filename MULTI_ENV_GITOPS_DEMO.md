# Podinfo - Multi-Environment GitOps with Image Automation

This demo showcases **advanced Flux GitOps capabilities**:

## 🎯 What This Demonstrates

### 1. **Multi-Environment GitOps Promotion**

- **Dev** → **Staging** → **Prod** environments
- Each environment has different configurations (replicas, resources, colors)
- Dependencies: Staging depends on Dev, Prod depends on Staging
- Git-based promotion workflow

### 2. **Image Automation**

- **ImageRepository**: Watches `ghcr.io/stefanprodan/podinfo` for new versions
- **ImagePolicy**: Uses semver policy (>=6.0.0)
- **ImageUpdateAutomation**: Automatically commits image updates to Git
- Flux creates Git commits when new images are available

### 3. **Kustomize Overlays**

- Base manifests in `base/` (includes podinfo + nginx sidecar)
- Environment-specific overlays in `dev/`, `staging/`, `prod/`
- Different replicas, resources, configurations, and ingress paths per environment
- Nginx sidecar handles path rewriting for ALB compatibility

### 4. **Health Monitoring**

- Health checks configured for each environment
- Flux monitors deployment health
- Visible in Weave GitOps UI

## 📁 Structure

```plaintext
k8s-app/podinfo/
├── base/                              # Base manifests
│   ├── deployment.yaml                # Podinfo + nginx sidecar
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── nginx-sidecar-configmap.yaml   # Nginx config for path rewriting
│   └── kustomization.yaml
├── dev/                               # Dev overlay (1 replica, red)
│   ├── namespace.yaml
│   └── kustomization.yaml
├── staging/                           # Staging overlay (2 replicas, yellow)
│   ├── namespace.yaml
│   └── kustomization.yaml
├── prod/                              # Prod overlay (3 replicas, green)
│   ├── namespace.yaml
│   └── kustomization.yaml
├── image-repository.yaml              # Watches container registry
├── image-policy.yaml                  # Defines image version policy
├── image-update-automation.yaml       # Auto-updates Git
├── kustomization-dev.yaml             # Flux Kustomization for dev
├── kustomization-staging.yaml         # Flux Kustomization for staging
└── kustomization-prod.yaml            # Flux Kustomization for prod
```

## 🚀 How It Works

### Environment Promotion Flow

1. **Update Base**: Change manifests in `k8s-app/podinfo/base/`
2. **Dev Syncs First**: Flux syncs to `podinfo-dev` namespace
3. **Staging Syncs After Dev**: Due to `dependsOn`, staging waits for dev
4. **Prod Syncs After Staging**: Prod waits for staging to be healthy

### Image Automation Flow

1. **New Image Released**: New podinfo version (e.g., 6.1.0) pushed to registry
2. **ImageRepository Detects**: Flux checks registry every 1 minute
3. **ImagePolicy Evaluates**: If version matches policy (>=6.0.0), it's approved
4. **ImageUpdateAutomation Updates Git**: Flux creates a commit updating image tags
5. **Kustomizations Sync**: All environments automatically deploy new version

## 🔍 Viewing in Weave GitOps

In Weave GitOps UI, you'll see:

- **Sources**:
  - `tf-aws-eks-flux-demo` (GitRepository)
  - `podinfo` (ImageRepository)

- **Applications**:
  - `podinfo-dev` (Kustomization)
  - `podinfo-staging` (Kustomization)
  - `podinfo-prod` (Kustomization)

- **Image Automation**:
  - `podinfo` (ImagePolicy)
  - `podinfo` (ImageUpdateAutomation)

## 🧪 Testing

### Check Environments

```bash
# Dev environment
kubectl get pods -n podinfo-dev
kubectl get kustomization podinfo-dev -n flux-system

# Staging environment
kubectl get pods -n podinfo-staging
kubectl get kustomization podinfo-staging -n flux-system

# Prod environment
kubectl get pods -n podinfo-prod
kubectl get kustomization podinfo-prod -n flux-system
```

### Access Applications

```bash
# Get ALB URL
ALB_URL=$(kubectl get ingress -A -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Access each environment via different paths
curl http://$ALB_URL/podinfo-dev      # Dev environment
curl http://$ALB_URL/podinfo-staging   # Staging environment
curl http://$ALB_URL/podinfo-prod      # Prod environment
```

**Note:** Each environment uses a different path because:

- ALB doesn't support path rewriting natively
- An nginx sidecar container rewrites paths: `/podinfo-{env}/*` → `/*`
- This allows all three environments to be accessible simultaneously

### Test Image Automation

1. Check current image version:

   ```bash
   kubectl get imagerepository podinfo -n flux-system -o yaml
   ```

2. Watch for new versions (Flux checks every 1 minute)

3. When new version is detected, Flux will:
   - Update ImagePolicy status
   - Create Git commit via ImageUpdateAutomation
   - Sync to all environments

## 🎨 Environment Differences

| Environment | Replicas | Color | Resources | Namespace | Path |
| ------------ | ---------- | ------- | ----------- | ----------- | ------ |
| **Dev** | 1 | Red (#ff6b6b) | 200m CPU, 256Mi RAM | podinfo-dev | `/podinfo-dev` |
| **Staging** | 2 | Yellow (#ffc107) | 300m CPU, 384Mi RAM | podinfo-staging | `/podinfo-staging` |
| **Prod** | 3 | Green (#6bcf7f) | 500m CPU, 512Mi RAM | podinfo-prod | `/podinfo-prod` |

## 🔄 Promotion Workflow

To promote changes:

1. **Update Base**: Modify files in `k8s-app/podinfo/base/`
2. **Commit & Push**: `git commit && git push`
3. **Watch Sync**:
   - Dev syncs first (5 min interval)
   - Staging syncs after dev is healthy
   - Prod syncs after staging is healthy

## 🏗️ Architecture Details

### Nginx Sidecar for Path Rewriting

Since AWS ALB doesn't support path rewriting natively, each podinfo pod includes an nginx sidecar container that:

- Listens on port 8080 (service targets this port)
- Rewrites paths: `/podinfo-{env}/*` → `/*` for podinfo
- Proxies requests to the podinfo container on port 9898
- Environment-specific nginx config is patched via Kustomize

This allows all three environments to be accessible simultaneously via different paths on the same ALB.

## 💼 Real-World Use Cases

### 1. **Software Development Lifecycle (SDLC)**

- **Dev**: Developers test new features quickly (1 replica, minimal resources)
- **Staging**: QA team validates before production (2 replicas, moderate resources)
- **Prod**: Production workload with high availability (3+ replicas, full resources)
- **Benefit**: Safe, automated promotion from dev → staging → prod

### 2. **Feature Flag Testing**

- Deploy feature branches to dev environment
- Promote to staging for integration testing
- Only promote to prod after validation
- **Benefit**: Catch issues early, reduce production incidents

### 3. **Compliance & Auditing**

- All changes tracked in Git (audit trail)
- Promotion requires successful health checks
- Can't skip environments (dependency enforcement)
- **Benefit**: Meets regulatory requirements (SOC2, HIPAA, etc.)

### 4. **Multi-Tenant Applications**

- Different environments for different customers/regions
- Same codebase, different configurations
- Isolated namespaces for security
- **Benefit**: Efficient resource usage, easy scaling

### 5. **Blue/Green Deployments**

- Staging can serve as "green" environment
- Prod is "blue" environment
- Test new version in staging, then promote
- **Benefit**: Zero-downtime deployments

### 6. **Cost Optimization**

- Dev: Minimal resources (cost-effective for development)
- Staging: Moderate resources (realistic testing)
- Prod: Full resources (production workload)
- **Benefit**: Reduce cloud costs while maintaining quality

### 7. **Team Collaboration**

- Developers work in dev environment
- QA team uses staging environment
- Operations manages prod environment
- **Benefit**: Clear separation of concerns, reduced conflicts

### 8. **Disaster Recovery Testing**

- Regularly promote to staging to test recovery procedures
- Validate backup/restore processes
- **Benefit**: Confidence in disaster recovery capabilities

## 🎯 When to Use This Pattern

### ✅ **Good Fit For:**

- Organizations with multiple environments
- Teams needing automated promotion workflows
- Applications requiring compliance/auditing
- Projects with frequent deployments
- Teams using Git-based workflows
- Microservices architectures
- Multi-tenant SaaS applications

### ⚠️ **Consider Alternatives If:**

- Single environment deployments
- Very simple applications (overkill)
- No need for environment promotion
- Prefer manual deployment processes
- Using different GitOps tools (ArgoCD, etc.)

## 🔧 Nginx Sidecar Pattern Use Cases

The nginx sidecar for path rewriting is useful when:

1. **ALB Limitations**: AWS ALB doesn't support path rewriting natively
2. **Legacy Applications**: Apps that serve at root `/` but need subpaths
3. **API Gateway Patterns**: Route multiple services through single ingress
4. **Path-Based Routing**: Different environments on same ALB
5. **Backward Compatibility**: Maintain old URLs while migrating

### Alternative Approaches

- **NGINX Ingress Controller**: If you can use it instead of ALB
- **Service Mesh** (Istio/Linkerd): More advanced routing capabilities
- **API Gateway** (Kong, Ambassador): Enterprise-grade routing
- **Application-Level Routing**: Modify app to handle subpaths

## 📊 Key Flux Features Demonstrated

✅ **Multi-Environment Management**
✅ **Kustomize Overlays**
✅ **Dependency Management** (dependsOn)
✅ **Image Automation**
✅ **Health Monitoring**
✅ **Git-based Workflows**
✅ **Reconciliation Status**
✅ **Weave GitOps UI Integration**
✅ **Sidecar Pattern** (nginx for path rewriting)
