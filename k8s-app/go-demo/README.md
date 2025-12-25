# Go Demo - Blue/Green Deployment Strategy

## Overview

The `go-demo` application uses **Blue/Green** deployment strategy. This allows you to:

- Deploy a new version (green) alongside the current version (blue)
- Test the new version via the preview service before promoting
- Instantly switch traffic to the new version when ready

## Architecture

- **Blue Deployment**: `go-demo-blue` - Current active version
- **Green Deployment**: `go-demo-green` - New version for testing
- **Active Service**: `go-demo` (port 80) - Routes production traffic to active version
- **Preview Service**: `go-demo-preview` (port 8080) - Routes to green version for testing

## How to Trigger a Blue/Green Deployment

### Method 1: Update the Image (via Git/Flux)

1. Update the image in `k8s-app/go-demo/deployment.yaml` for the green deployment:

   ```yaml
   # In go-demo-green deployment
   containers:
     - name: go-demo
       image: hashicorp/http-echo:latest
       args:
         - -text="Hello from Go Demo Green v2!"  # Update message
   ```

2. Commit and push to your Git repository
3. Flux will automatically sync the change
4. Green deployment will be updated with new version

### Method 2: Update via kubectl (for testing)

```bash
# Update the green deployment image
kubectl set image deployment/go-demo-green go-demo=hashicorp/http-echo:latest

# Or update the args
kubectl patch deployment go-demo-green --type=json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args/0", "value": "-text=\"Hello from Go Demo Green v2!\""}]'
```

## What Happens During Blue/Green Deployment

1. **New Version Deployed**: Green deployment is updated with new image/configuration
2. **Preview Service**: The `go-demo-preview` service points to green pods
3. **Active Service**: The `go-demo` service continues pointing to blue pods
4. **Testing**: You can test the new version via the preview service
5. **Promotion**: When ready, switch the active service selector to green

## How to Promote (Switch Traffic to New Version)

### Via Git/Flux (Recommended)

1. Update `k8s-app/go-demo/service.yaml`:

   ```yaml
   selector:
     app: go-demo
     version: green  # Change from "blue" to "green"
   ```

2. Commit and push to Git
3. Flux will sync the change
4. Traffic instantly switches to green version

### Via kubectl (for testing)

```bash
# Patch the service to switch to green
kubectl patch service go-demo --type=json -p='[{"op": "replace", "path": "/spec/selector/version", "value": "green"}]'

# Verify the switch
kubectl get endpoints go-demo
```

## Testing the Preview Version

### Via Port Forward

```bash
# Forward preview service to localhost
kubectl port-forward svc/go-demo-preview 8080:8080

# Test in another terminal
curl http://localhost:8080
```

### Via Ingress (if configured)

If you have an Ingress pointing to the preview service, you can access it via the ALB URL.

## Rollback

If the new version has issues, switch back to blue:

```bash
# Switch service back to blue
kubectl patch service go-demo --type=json -p='[{"op": "replace", "path": "/spec/selector/version", "value": "blue"}]'
```

Or update the service.yaml in Git and let Flux sync it.

## Key Features

- **Instant Traffic Switch**: Zero-downtime deployment with immediate traffic shift
- **Full Testing**: Test new version completely before switching traffic
- **Manual Control**: You decide when to promote via Git or kubectl
- **Easy Rollback**: Can switch back to blue version instantly
- **Separate Environments**: Blue and green run independently

## Example Workflow

1. **Deploy new version to green**:

   ```bash
   kubectl set image deployment/go-demo-green go-demo=hashicorp/http-echo:latest
   ```

2. **Wait for green pods to be ready**:

   ```bash
   kubectl get pods -l app=go-demo,version=green -w
   ```

3. **Test preview version**:

   ```bash
   kubectl port-forward svc/go-demo-preview 8080:8080
   curl http://localhost:8080
   ```

4. **Promote to active**:

   ```bash
   kubectl patch service go-demo --type=json -p='[{"op": "replace", "path": "/spec/selector/version", "value": "green"}]'
   ```

5. **Verify traffic switched**:

   ```bash
   kubectl get endpoints go-demo
   # Should show green pod IPs
   ```

6. **Scale down blue** (optional, after verification):

   ```bash
   kubectl scale deployment go-demo-blue --replicas=0
   ```
