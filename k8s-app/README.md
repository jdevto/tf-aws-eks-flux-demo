# Kubernetes Application Manifests

This directory contains Kubernetes manifests for applications managed by Flux GitOps.

## Applications

### Podinfo - Multi-Environment GitOps

**Location:** `k8s-app/podinfo/`

Advanced Flux GitOps demonstration featuring:

- Multi-environment promotion (Dev → Staging → Prod)
- Image automation with automatic Git commits
- Kustomize overlays for environment-specific configurations
- Dependency management between environments
- Health monitoring and reconciliation status
- Nginx sidecar for path rewriting (ALB compatibility)

**Environments:**

- `podinfo-dev` - Development (1 replica, red theme) - Accessible at `/podinfo-dev`
- `podinfo-staging` - Staging (2 replicas, yellow theme) - Accessible at `/podinfo-staging`
- `podinfo-prod` - Production (3 replicas, green theme) - Accessible at `/podinfo-prod`

**Documentation:** See [`MULTI_ENV_GITOPS_DEMO.md`](../MULTI_ENV_GITOPS_DEMO.md) for detailed documentation, use cases, and architecture details.

### Simple App - Basic GitOps

**Location:** `k8s-app/simple-app/`

Basic GitOps sync demonstration showing how Flux automatically syncs Kubernetes resources from Git.

### Weave GitOps - GitOps UI

**Location:** `k8s-app/weave-gitops/`

Weave GitOps Core provides a web UI for managing Flux GitOps workflows, viewing sources, applications, and image automation.

### Welcome Page

**Location:** `k8s-app/welcome/`

Landing page with links to all demo applications.

## ALB Configuration

All applications use **shared ALB** via Ingress resources instead of LoadBalancer Services.

### Key Points

1. **Services should be ClusterIP or NodePort** (not LoadBalancer)
   - The ALB is created by the Ingress resource
   - Services are only used for internal routing

2. **Shared ALB via IngressGroup**
   - All Ingresses use `alb.ingress.kubernetes.io/group.name: demo-apps`
   - This ensures they share the same ALB instance
   - More cost-effective than separate ALBs

3. **Path-based Routing**
   - `/` → Welcome page
   - `/podinfo-dev` → Podinfo Dev environment
   - `/podinfo-staging` → Podinfo Staging environment
   - `/podinfo-prod` → Podinfo Prod environment
   - `/simple` → Simple app

### Example Service (ClusterIP)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  type: ClusterIP  # NOT LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: my-app
```

### Ingress Annotations Explained

- `kubernetes.io/ingress.class: alb` - Use AWS Load Balancer Controller
- `alb.ingress.kubernetes.io/group.name: demo-apps` - Share ALB with other Ingresses
- `alb.ingress.kubernetes.io/scheme: internet-facing` - Public ALB
- `alb.ingress.kubernetes.io/target-type: ip` - Direct pod IP targeting

### Verifying ALB

After deployment, check the Ingress:

```bash
kubectl get ingress -A
kubectl describe ingress podinfo -n podinfo-dev
kubectl describe ingress simple-app
```

The `ADDRESS` field will show the ALB DNS name. All Ingresses should show the same ALB address when using the same group name.
