# Nginx Demo - Canary Deployment Strategy

## Overview

The `nginx-demo` application uses **Canary** deployment strategy. This allows you to:

- Gradually shift traffic from old version to new version
- Monitor the new version with real production traffic
- Control traffic percentage via ALB weighted target groups
- Rollback easily if issues are detected

## Architecture

- **Stable Deployment**: `nginx-demo-stable` - Current stable version (nginx:1.25-alpine)
- **Canary Deployment**: `nginx-demo-canary` - New version for testing (nginx:1.26-alpine)
- **Stable Service**: `nginx-demo-stable` - Routes to stable pods
- **Canary Service**: `nginx-demo-canary` - Routes to canary pods
- **Traffic Routing**: ALB weighted target groups split traffic between services

## Current Traffic Split

- **75% Stable**: Routes to `nginx-demo-stable` service
- **25% Canary**: Routes to `nginx-demo-canary` service

Traffic split is controlled via ALB action annotation in `ingress.yaml`.

## How to Trigger a Canary Deployment

### Method 1: Update the Image (via Git/Flux)

1. Update the image in `k8s-app/nginx-demo/deployment.yaml` for the canary deployment:

   ```yaml
   # In nginx-demo-canary deployment
   containers:
     - name: nginx
       image: nginx:1.27-alpine  # Update to new version
   ```

2. Commit and push to your Git repository
3. Flux will automatically sync the change
4. Canary deployment will be updated with new version
5. Traffic will be split according to weights in ingress

### Method 2: Update via kubectl (for testing)

```bash
# Update the canary deployment image
kubectl set image deployment/nginx-demo-canary nginx=nginx:1.27-alpine
```

## Adjusting Canary Traffic Percentage

### Via Git/Flux (Recommended)

1. Update `k8s-app/nginx-demo/ingress.yaml`:

   ```yaml
   alb.ingress.kubernetes.io/actions.nginx-canary: |
     {
       "Type": "forward",
       "ForwardConfig": {
         "TargetGroups": [
           {"ServiceName": "nginx-demo-stable", "ServicePort": "80", "Weight": 90},
           {"ServiceName": "nginx-demo-canary", "ServicePort": "80", "Weight": 10}
         ]
       }
     }
   ```

   This changes traffic split to 90% stable, 10% canary.

2. Commit and push to Git
3. Flux will sync and ALB will update traffic weights

### Via kubectl (for testing)

```bash
# Patch the ingress annotation
kubectl patch ingress nginx-demo --type=json -p='[{"op": "replace", "path": "/metadata/annotations/alb.ingress.kubernetes.io~1actions.nginx-canary", "value": "{\"Type\":\"forward\",\"ForwardConfig\":{\"TargetGroups\":[{\"ServiceName\":\"nginx-demo-stable\",\"ServicePort\":\"80\",\"Weight\":90},{\"ServiceName\":\"nginx-demo-canary\",\"ServicePort\":\"80\",\"Weight\":10}]}}"}]'
```

## Progressive Canary Steps

To implement a progressive canary (25% → 50% → 75% → 100%), manually update the weights:

1. **Start with 25% canary**:
   - Stable: 75, Canary: 25

2. **After verification, increase to 50%**:
   - Stable: 50, Canary: 50

3. **After verification, increase to 75%**:
   - Stable: 25, Canary: 75

4. **Finally, promote to 100%**:
   - Update stable deployment to new version
   - Set weights to Stable: 100, Canary: 0
   - Or scale down canary deployment

## Monitoring the Canary Deployment

### Check Pods

```bash
# See both stable and canary pods
kubectl get pods -l app=nginx-demo

# Check which pods are stable vs canary
kubectl get pods -l app=nginx-demo,version=stable
kubectl get pods -l app=nginx-demo,version=canary
```

### Check Services

```bash
# Stable service (majority of traffic)
kubectl get svc nginx-demo-stable

# Canary service (new version traffic)
kubectl get svc nginx-demo-canary

# Check service endpoints
kubectl get endpoints nginx-demo-stable
kubectl get endpoints nginx-demo-canary
```

### Check Traffic Distribution

```bash
# View ALB target group weights (via AWS CLI)
aws elbv2 describe-target-groups --region <region> \
  --query 'TargetGroups[?contains(TargetGroupName, `nginx-demo`)].{Name:TargetGroupName,Port:Port}'

# Check Ingress status
kubectl get ingress nginx-demo -o yaml
```

## Testing During Canary

### Via ALB URL

```bash
# Get the ALB URL
ALB_URL=$(kubectl get ingress nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Make multiple requests to see traffic distribution
for i in {1..20}; do
  curl -s http://$ALB_URL/ | grep -o "nginx/[0-9.]*"
done
```

### Via Port Forward

```bash
# Forward stable service
kubectl port-forward svc/nginx-demo-stable 8080:80

# Forward canary service (in another terminal)
kubectl port-forward svc/nginx-demo-canary 8081:80

# Test both
curl http://localhost:8080  # Stable version
curl http://localhost:8081   # Canary version
```

## Rollback

If issues are detected during the canary:

```bash
# Option 1: Set canary weight to 0
# Update ingress to set canary weight to 0

# Option 2: Scale down canary deployment
kubectl scale deployment nginx-demo-canary --replicas=0

# Option 3: Update canary back to stable version
kubectl set image deployment/nginx-demo-canary nginx=nginx:1.25-alpine
```

## Promoting Canary to Stable

When canary is proven stable:

1. **Update stable deployment to new version**:

   ```bash
   kubectl set image deployment/nginx-demo-stable nginx=nginx:1.26-alpine
   ```

2. **Set traffic weights to 100% stable**:

   Update ingress annotation:

   ```yaml
   {"ServiceName": "nginx-demo-stable", "ServicePort": "80", "Weight": 100},
   {"ServiceName": "nginx-demo-canary", "ServicePort": "80", "Weight": 0}
   ```

3. **Scale down canary** (optional):

   ```bash
   kubectl scale deployment nginx-demo-canary --replicas=0
   ```

## Key Features

- **Gradual Traffic Shift**: Reduces risk by exposing new version to small percentage first
- **Manual Control**: You control traffic percentage via Git or kubectl
- **Real Production Traffic**: Tests with actual user traffic, not synthetic
- **Easy Rollback**: Can reduce canary weight or scale down canary deployment
- **ALB Integration**: Uses AWS ALB weighted target groups for traffic splitting

## Example Workflow

1. **Deploy new version to canary**:

   ```bash
   kubectl set image deployment/nginx-demo-canary nginx=nginx:1.27-alpine
   ```

2. **Start with 25% traffic** (already configured in ingress)

3. **Monitor at 25% traffic**:

   ```bash
   # Check metrics, logs, errors
   kubectl logs -l app=nginx-demo,version=canary --tail=50
   ```

4. **After verification, increase to 50%**:

   Update ingress weights to 50/50

5. **After verification, increase to 75%**:

   Update ingress weights to 25/75

6. **Promote to stable**:

   Update stable deployment and set weights to 100/0
