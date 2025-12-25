# Weave GitOps Core

Weave GitOps Core provides a web UI for managing Flux GitOps workflows.

## What's Included

- **Deployment**: Weave GitOps Core application
- **Service**: ClusterIP service on port 9001
- **ServiceAccount & RBAC**: Permissions to read Flux resources
- **Ingress** (optional): Exposes the dashboard via ALB

## Access

### Port Forward (Development)

```bash
kubectl -n flux-system port-forward svc/weave-gitops 9001:9001
```

Then visit: <http://localhost:9001>

### Via Ingress/ALB

If Ingress is enabled, access via the ALB URL:

```bash
kubectl get ingress -n flux-system weave-gitops
```

## Secret Management

The `cluster-user-auth` secret is automatically managed by **External Secrets Operator** (ESO), which syncs from **AWS Secrets Manager**.

### How It Works

1. **Terraform** creates the secret in AWS Secrets Manager (`modules/external-secrets`)
2. **External Secrets Operator** (installed via Terraform) syncs the secret to Kubernetes
3. **Weave GitOps** deployment uses the synced secret automatically

### Updating the Password

Update the password in AWS Secrets Manager:

```bash
# Generate new bcrypt hash
PASSWORD_HASH=$(echo -n "new-password" | gitops get bcrypt-hash)

# Update in AWS Secrets Manager (secret name from Terraform output)
aws secretsmanager update-secret \
  --secret-id <cluster-name>/weave-gitops/cluster-user-auth \
  --secret-string "{\"username\":\"admin\",\"password\":\"$PASSWORD_HASH\"}"
```

External Secrets Operator will automatically sync the updated secret to Kubernetes.

## Default Credentials

- Username: `admin`
- Password: Set when creating the `cluster-user-auth` secret

## Features

- Visual GitOps dashboard
- Flux resource management
- Application status monitoring
- Git repository visualization

## Alternatives

Other GitOps UI options:

1. **Weave GitOps Core** (this) - Official Flux UI, free/open source
2. **Argo CD** - Full-featured GitOps tool with UI (but uses Argo, not Flux)
3. **Flux Web UI** - Community projects (limited)
4. **Lens** - Desktop Kubernetes IDE (not web-based)
5. **Rancher** - Full Kubernetes management platform

For Flux users, Weave GitOps Core is the recommended choice as it's built specifically for Flux.
