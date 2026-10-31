# EKS upgrade runbook

Where each upgrade step lives in this repo, and the order to run them.
Example used throughout: **1.35 → 1.36**.

```
0. Pre-checks → 1. Control plane (TF) → 2. Managed add-ons (TF) →
3. Managed node group (TF → EKS) → 4. Karpenter nodes (drift) → 5. Helm tools (Git → Argo CD)
```

Always: **dev first**, then test, then prod, with the same commits.

## Where things are

| Step | What | File in this repo | Trigger | Rollback |
|---|---|---|---|---|
| 0 | Pre-checks | kubent / pluto, EKS Upgrade Insights | you | — |
| 1 | Control plane | `live/<acct>/02-eks/terraform.tfvars` → `cluster_version` | `terraform apply` | **not possible** |
| 2 | Managed add-ons | `live/<acct>/02-eks/terraform.tfvars` → `addon_versions` | `terraform apply -target` one at a time | previous version, apply |
| 3 | Platform node group | `modules/eks/nodes.tf` → `version = aws_eks_cluster.main.version` (automatic) and `platform_node_release_version` in tfvars | `terraform apply`, EKS rolls | previous release, apply |
| 4 | Karpenter nodes | gitops repo `EC2NodeClass.amiSelectorTerms` | drift (automatic) | pin the older AMI alias |
| 5 | Helm tools | gitops repo `applications/platform/*.yaml` → `targetRevision` | git merge, Argo CD syncs | `git revert` |
| — | Karpenter IAM | `modules/eks/karpenter.tf` | `terraform apply` **before** step 5 | — |
| — | Argo CD itself | `startup-argocd.sh` → `--version` | `helm upgrade` | previous `--version` |

Resource definitions are in `modules/eks/`. The `02-eks` folders only pass values.

## Step 0: pre-checks (before anything changes)

Compatibility is checked **before** touching the control plane. The control plane
cannot be rolled back, so an incompatibility found afterwards is expensive. If a
tool does not support the target version, upgrade **that tool first**.

| Check | How |
|---|---|
| Deprecated / removed APIs in use | `kubent`, `pluto`, or EKS console → Upgrade insights |
| Add-on versions for the target | `aws eks describe-addon-versions --kubernetes-version 1.36 --addon-name coredns` (all 5) |
| Helm tools support the target | compatibility matrix: Karpenter, AWS LBC, ESO, kube-prometheus-stack |
| Workloads survive drains | replicas ≥ 2, PDBs, readiness probes, `preStop` delay |
| Proof of zero downtime | continuous `curl` loop against the ALB, left running through the upgrade |

Rules: ~14 months of standard support per version; **one minor at a time**
(1.35 → 1.36, never 1.35 → 1.37).

## Step 1: control plane (Terraform)

```hcl
# live/dev/02-eks/terraform.tfvars
cluster_version = "1.36"   # was "1.35"
```

```sh
terraform -chdir=live/dev/02-eks init -backend-config=backend.hcl
terraform -chdir=live/dev/02-eks plan  -var-file=../account.tfvars   # expect: update in-place, version only
terraform -chdir=live/dev/02-eks apply -var-file=../account.tfvars   # 10-20 min
kubectl version                                                     # Server Version: v1.36.x
```

- AWS rolls the API servers. **No app downtime**: pods, ALB, RDS are not on this path.
- kubectl, Argo CD, Karpenter, HPA may see short API blips. They retry.
- **No rollback.**
- Does **not** upgrade add-ons or nodes.

## Step 2: managed add-ons (Terraform)

The 5 add-ons in `modules/eks/addons.tf`: `vpc-cni`, `kube-proxy`, `coredns`,
`eks-pod-identity-agent`, `aws-ebs-csi-driver`. Every one is pinned by
`addon_version`. Without the pin Terraform never upgrades them.

```sh
# what's running
aws eks describe-addon --cluster-name demoapp-dev-eks --addon-name coredns \
  --query 'addon.[addonVersion,status]' --output text

# what's compatible with 1.36
aws eks describe-addon-versions --kubernetes-version 1.36 --addon-name coredns \
  --query 'addons[].addonVersions[].{v:addonVersion,default:compatibilities[0].defaultVersion}' --output table
```

Update `addon_versions` in tfvars, then apply **one at a time**:

```sh
cd live/dev/02-eks
terraform apply -var-file=../account.tfvars -target=module.eks.aws_eks_addon.kube_proxy
terraform apply -var-file=../account.tfvars -target=module.eks.aws_eks_addon.vpc_cni     # one minor per step
terraform apply -var-file=../account.tfvars -target=module.eks.aws_eks_addon.coredns
terraform apply -var-file=../account.tfvars -target=module.eks.aws_eks_addon.pod_identity_agent
terraform apply -var-file=../account.tfvars -target=module.eks.aws_eks_addon.ebs_csi
terraform apply -var-file=../account.tfvars

kubectl -n kube-system rollout status ds/kube-proxy
kubectl -n kube-system rollout status ds/aws-node
kubectl -n kube-system rollout status deploy/coredns
kubectl run dnstest --rm -it --image=busybox --restart=Never -- nslookup kubernetes.default
```

| Add-on | Runs as | Why no app downtime |
|---|---|---|
| kube-proxy | DaemonSet | one node at a time, existing iptables rules stay |
| vpc-cni | DaemonSet | running pods keep IPs, only new pods wait a few seconds |
| coredns | Deployment ×2 | one pod at a time, one always answers |
| pod-identity-agent | DaemonSet | pods hold cached credentials |
| ebs-csi | Deployment + DaemonSet | mounted volumes stay mounted |

`resolve_conflicts_on_update = "PRESERVE"` keeps manual config tweaks;
`OVERWRITE` resets them. Rollback: previous `addon_version`, apply. Never
upgrade from the console: state stops matching and the next apply undoes it.

## Step 3: platform managed node group (Terraform triggers, EKS rolls)

`modules/eks/nodes.tf` has `version = aws_eks_cluster.main.version`, so the
node group follows the control plane in the **same apply** as step 1. Nothing
extra to change in dev. In prod, also bump `platform_node_release_version`.

What EKS does (Terraform waits):

```
Start:        [old-1] [old-2]
Scale up:     [old-1] [old-2] [new-1] [new-2]     # old ones cordoned
Drain old-1:  [old-2] [new-1] [new-2]              # pods moved, old-1 terminated
Drain old-2:  [new-1] [new-2]                      # back to 2 nodes
```

Pace: `update_config { max_unavailable = 1 }`. Failure mode: a pod not evictable
in 15 min (single replica + PDB `minAvailable: 1`) → `PodEvictionFailure`.
`force_update_version = true` pushes through but causes downtime.

```sh
kubectl get nodes -L role,eks.amazonaws.com/nodegroup -w
```

## Step 4: Karpenter nodes (automatic via drift)

App pods run on Karpenter-launched EC2 (label `role=workload`). Nothing in
Terraform except IAM (`modules/eks/karpenter.tf`).

| EC2NodeClass | What you do | When nodes roll |
|---|---|---|
| `alias: al2023@latest` (dev) | nothing | after control plane upgrade, and whenever AWS ships a new AMI |
| `alias: al2023@v20260901` (prod) | bump the date in gitops, PR, merge | only when the bump is merged |

Drift flow: node AMI ≠ what EC2NodeClass resolves → node **drifted** → new node
launched → old node cordoned + drained (respects PDBs) → terminated, paced by
`disruption.budgets`.

Karpenter drift ≠ Argo CD drift. Argo CD: live ≠ Git. Karpenter: running node ≠ NodePool/EC2NodeClass.

```sh
kubectl get nodes -L karpenter.sh/nodepool -w
kubectl get nodeclaims -w
```

## Step 5: Helm tools (Git → Argo CD)

| Tool | Pin | Effect |
|---|---|---|
| Karpenter | `"1.14.1"` | exact, changes only via PR |
| kube-prometheus-stack | `"90.*"` | floats, any 90.x applied automatically |
| AWS LBC | `"3.5.*"` | floats on patch |
| External Secrets | `"2.10.*"` | floats on patch |
| metrics-server | `"3.*"` | floats on minor |

For prod, pin exact versions everywhere. A wildcard is an upgrade without review.

Flow (Karpenter 1.14.1 → 1.15.0):

1. Read release notes for every version in between: CRD changes, renamed values, k8s compatibility.
2. `helm show values` old vs new, diff the keys you set.
3. **Karpenter only:** new IAM needed? It lives in `modules/eks/karpenter.tf`. Apply that **first**.
4. Bump `targetRevision` in gitops, PR, review, merge.
5. Argo CD: root app updates the Application → OutOfSync → auto-sync (server-side apply) → Deployment rolls.
6. Verify, promote to prod. Rollback = `git revert`.

```sh
kubectl -n argocd get application karpenter       # Synced / Healthy
kubectl -n karpenter logs deploy/karpenter | grep -i error
kubectl get nodepools,ec2nodeclasses              # Ready=True
```

## Argo CD itself

Not managed by an Application, so it cannot upgrade itself. Pin the chart:

```sh
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --version 9.x.y
```

Better: bootstrap once with Helm, then add an `argocd.yaml` Application so
Argo CD manages itself and its upgrade is a Git bump too.

## Why the app stays up

| Setting | Why |
|---|---|
| `replicas: 2+` / HPA `min: 2` | one pod moves while the other serves |
| PodDisruptionBudget | drains wait instead of evicting every replica |
| topologySpreadConstraints | replicas not all on the node being drained |
| readinessProbe | new pods get traffic only when ready |
| ALB deregistration delay + `preStop: sleep` | in-flight requests finish |
| Karpenter `disruption.budgets` | caps how many app nodes roll at once |

## Promotion across accounts

| | dev | test | prod |
|---|---|---|---|
| `cluster_version` | 1.36 (soaking) | 1.36 | 1.35 (promoted after test) |
| `platform_node_release_version` | `null` (latest) | `null` | pinned `1.35.x-2026xxxx` |
| `endpoint_public_access` | true | false | false |
| Karpenter AMI alias (gitops) | `al2023@latest` | `al2023@latest` | `al2023@v2026xxxx` |

The PR that promotes to prod changes **only** `live/prod/02-eks/terraform.tfvars`.
The plan for dev and test is empty, and that empty plan is what the reviewer sees.

## Interview answer (about 60 seconds)

> Order matters, and it starts before anything changes. First I check for
> deprecated APIs with kubent or EKS Upgrade Insights, and confirm the add-ons,
> Karpenter, the Load Balancer Controller and External Secrets all support the
> target version, upgrading any that don't. I do dev first, with a continuous
> request loop running to prove zero downtime. Then I bump `cluster_version`
> in the 02-eks tfvars, one minor at a time. AWS rolls the API servers, pods
> aren't affected, but there's no rollback, which is why the pre-checks matter.
> Next the managed add-ons: all five pinned in Terraform and applied one at a
> time. Then the nodes: the managed node group follows the cluster version and
> does a surge-then-drain roll that respects PDBs; Karpenter replaces its own
> nodes through drift when the AMI changes, pinned in prod so that's deliberate.
> Finally the Helm tools are Argo CD Applications, so that's a PR bumping the
> chart version, with rollback by git revert. The app stays up because every
> service runs two or more replicas with PDBs, topology spread, readiness probes
> and a preStop delay.
