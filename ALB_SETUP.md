# ALB Setup Guide

This document explains how ALB (Application Load Balancer) is configured to replace Classic Load Balancer for the demo applications.

## Architecture Overview

Instead of using Kubernetes `Service` type `LoadBalancer` (which creates Classic Load Balancers), we use:

1. **AWS Load Balancer Controller** - Manages ALB provisioning
2. **Ingress Resources** - Define routing rules
3. **Shared ALB** - Both apps share one ALB via IngressGroup

## Components

### 1. AWS Load Balancer Controller Module (`modules/aws-lb-controller`)

**What it does:**

- Creates IAM role with proper permissions for ALB management
- Uses IRSA (IAM Roles for Service Accounts) for secure access
- Installs AWS Load Balancer Controller via Helm
- Tags subnets appropriately for ALB placement

**Key Features:**

- **IRSA**: More secure than instance profiles, follows AWS best practices
- **Subnet Tagging**: Automatically tags public/private subnets for ALB discovery
- **IAM Policy**: Comprehensive permissions for ALB lifecycle management

### 2. Ingress Resources

**Location:** `k8s-app/podinfo/base/ingress.yaml` and `k8s-app/simple-app/ingress.yaml`

**Key Annotations:**

- `kubernetes.io/ingress.class: alb` - Use AWS Load Balancer Controller
- `alb.ingress.kubernetes.io/group.name: demo-apps` - **Share ALB** between Ingresses
- `alb.ingress.kubernetes.io/scheme: internet-facing` - Public ALB
- `alb.ingress.kubernetes.io/target-type: ip` - Direct pod IP targeting

**Routing:**

- Path-based routing: `/podinfo` → podinfo, `/simple` → simple-app, `/` → welcome
- Alternative: Host-based routing (see `k8s-app/README.md`)

### 3. Services

**Important:** Services should be `ClusterIP` (not `LoadBalancer`)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: podinfo
spec:
  type: ClusterIP  # NOT LoadBalancer
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: podinfo
```

## Why This Approach?

### Benefits

1. **Cost Efficiency**: One ALB shared between apps vs. multiple Classic LBs
2. **Modern**: ALB supports advanced features (WAF, path-based routing, etc.)
3. **Security**: IRSA is more secure than instance profiles
4. **Flexibility**: Easy to add more apps to the shared ALB
5. **Best Practice**: Follows AWS EKS recommended patterns

### Comparison

| Aspect | Classic LB (Service) | ALB (Ingress) |
| ------ | ------------------- | ------------- |
| Cost | One per Service | Shared via IngressGroup |
| Features | Basic | Advanced (WAF, path routing, etc.) |
| Management | Kubernetes native | AWS Load Balancer Controller |
| Security | Instance profile | IRSA (more secure) |

## Implementation Details

### Module Dependencies

```plaintext
VPC → EKS → AWS-LB-Controller → Flux
```

The AWS Load Balancer Controller must be installed before Flux syncs the Ingress resources.

### Subnet Requirements

The module automatically tags subnets:

- **Public subnets**: `kubernetes.io/role/elb=1` (for internet-facing ALBs)
- **Private subnets**: `kubernetes.io/role/internal-elb=1` (for internal ALBs)
- **All subnets**: `kubernetes.io/cluster/<cluster-name>=shared`

### OIDC Issuer URL

**Note:** The EKS module outputs the OIDC issuer URL from the cluster resource:

```hcl
# In modules/eks/main.tf, the OIDC provider is created from:
aws_eks_cluster.this.identity[0].oidc[0].issuer
```

## Verification

After deployment:

```bash
# Check controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check Ingress resources
kubectl get ingress

# Both should show the same ALB address
kubectl describe ingress podinfo -n podinfo-dev
kubectl describe ingress simple-app
```

## Troubleshooting

### ALB not created

- Check controller logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`
- Verify IAM role permissions
- Check subnet tags: `aws ec2 describe-subnets --subnet-ids <subnet-id>`

### Ingresses not sharing ALB

- Verify both use the same `alb.ingress.kubernetes.io/group.name` annotation
- Check Ingress order/priority if using path-based routing

### 403 Forbidden errors

- Verify IRSA is working: `kubectl describe sa aws-load-balancer-controller -n kube-system`
- Check IAM role trust policy includes the service account

## References

- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [IngressGroup Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/ingress_groups/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
