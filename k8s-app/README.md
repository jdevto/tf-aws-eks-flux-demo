# Kubernetes Application Manifests

This directory contains Kubernetes manifests for applications managed by Flux.

## ALB Configuration

Both `nginx-demo` and `go-demo` use **shared ALB** via Ingress resources instead of LoadBalancer Services.

### Key Points

1. **Services should be ClusterIP or NodePort** (not LoadBalancer)
   - The ALB is created by the Ingress resource
   - Services are only used for internal routing

2. **Shared ALB via IngressGroup**
   - Both Ingresses use `alb.ingress.kubernetes.io/group.name: demo-apps`
   - This ensures they share the same ALB instance
   - More cost-effective than separate ALBs

3. **Path-based Routing**
   - `/nginx-demo/*` → nginx-demo service
   - `/go-demo/*` → go-demo service
   - `/` → nginx-demo (default)

### Example Service (ClusterIP)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-demo
spec:
  type: ClusterIP  # NOT LoadBalancer
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: nginx-demo
```

### Ingress Annotations Explained

- `kubernetes.io/ingress.class: alb` - Use AWS Load Balancer Controller
- `alb.ingress.kubernetes.io/group.name: demo-apps` - Share ALB with other Ingresses
- `alb.ingress.kubernetes.io/scheme: internet-facing` - Public ALB
- `alb.ingress.kubernetes.io/target-type: ip` - Direct pod IP targeting

### Alternative: Host-based Routing

If you prefer host-based routing instead of path-based:

```yaml
spec:
  rules:
    - host: nginx-demo.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-demo
                port:
                  number: 80
```

### Verifying ALB

After deployment, check the Ingress:

```bash
kubectl get ingress
kubectl describe ingress nginx-demo
kubectl describe ingress go-demo
```

The `ADDRESS` field will show the ALB DNS name. Both Ingresses should show the same ALB address when using the same group name.
