# tf-aws-eks-flux-demo

Terraform demo for Amazon EKS with Flux GitOps.

## What this demo does

* **Terraform** provisions:
  * VPC (from local module `modules/vpc`)
  * EKS (from local module `modules/eks`, using native AWS resources)
  * AWS Load Balancer Controller (installed via Helm with IRSA) for ALB management
  * Flux (installed via Helm)
  * Flux Workloads (bootstraps `GitRepository` and `Kustomization` CRs via `modules/flux-workloads`)
* **Flux** then fully manages **sample workloads**:
  * **nginx-demo** (nginx-based) from `k8s-app/nginx-demo`
  * **go-demo** (Go-based with rate limiting) from `k8s-app/go-demo`
  * **weave-gitops** (GitOps UI) from `k8s-app/weave-gitops`
  * All use **Ingress resources with shared ALB** (not LoadBalancer Services)

## Repo structure

```plaintext
.
├── main.tf
├── providers.tf
├── versions.tf
├── variables.tf
├── outputs.tf
├── locals.tf
├── modules
│   ├── vpc
│   ├── eks
│   ├── flux
│   └── flux-workloads
└── k8s-app
    ├── nginx-demo
    ├── go-demo
    └── weave-gitops

```

## Prereqs

* Terraform >= 1.6
* AWS credentials configured (env vars, shared config, or SSO)
* `kubectl`
* `aws` CLI

## Configure the Git repo URL (important)

Flux needs a real Git repo URL that contains this repo content.

Recommended: pass it on apply:

```bash
terraform apply -var='repo_url=https://github.com/<you>/<this-repo>.git'
```

The Flux Kustomizations will point at `k8s-app/nginx-demo`, `k8s-app/go-demo`, and `k8s-app/weave-gitops` in that repo.

## Run the demo

```bash
terraform init
terraform apply
```

Then configure kubectl (adjust region/name if you changed defaults in `variables.tf`):

```bash
aws eks update-kubeconfig --region ap-southeast-2 --name eks-flux-demo
kubectl get nodes
```

## Verify AWS Load Balancer Controller

Check the controller is running:

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

## Verify Flux Installation

Check Flux components are running:

```bash
kubectl get pods -n flux-system
```

Check GitRepository status:

```bash
kubectl get gitrepository -n flux-system
kubectl describe gitrepository flux-demo-repo -n flux-system
```

Check Kustomization status:

```bash
kubectl get kustomization -n flux-system
kubectl describe kustomization nginx-demo -n flux-system
kubectl describe kustomization go-demo -n flux-system
kubectl describe kustomization weave-gitops -n flux-system
```

## Verify the sample app ALB

Both apps share a single ALB via Ingress resources:

```bash
# Check Ingress resources (they share the same ALB)
kubectl get ingress
kubectl describe ingress nginx-demo
kubectl describe ingress go-demo

# The ADDRESS field shows the shared ALB DNS name
# Both Ingresses should show the same ALB address
```

The ALB will be created automatically by the AWS Load Balancer Controller when the Ingress resources are applied by Flux.

**Note**: Services should be `ClusterIP` type (not `LoadBalancer`). See `k8s-app/README.md` for details.

## Monitor Flux Sync Status

Watch Kustomization resources for sync status:

```bash
kubectl get kustomization -n flux-system -w
```

Check Flux logs:

```bash
kubectl logs -n flux-system -l app=kustomize-controller --tail=50
kubectl logs -n flux-system -l app=source-controller --tail=50
```

## Clean destroy (including LBs)

```bash
terraform destroy
```

Because Terraform bootstraps the Flux `GitRepository` and `Kustomization` CRs (with finalizers), Flux will prune the app resources (and the AWS ELB created by the Service) before Flux/EKS/VPC are destroyed.

If you hit `Kubernetes cluster unreachable` during destroy, do a 2-phase destroy (addons first, then infra):

```bash
terraform destroy -target=module.flux_workloads -auto-approve
terraform destroy -target=module.flux -auto-approve
terraform destroy -auto-approve
```

Note: The GitRepository and Kustomization resources are applied/deleted via `kubectl` from Terraform (to avoid CRD planning issues), so `terraform apply/destroy` should be run from a machine that has `aws` + `kubectl` available and valid AWS credentials.

## Differences from Argo CD

* Flux uses `GitRepository` + `Kustomization` CRs instead of `Application` CRs
* Flux doesn't have a built-in web UI (but Weave GitOps Core provides one)
* Flux syncs automatically based on the configured interval (default: 5 minutes)
* Flux uses Kustomize for resource management (similar to Argo CD)

## About

Terraform demo for Amazon EKS with Flux GitOps
