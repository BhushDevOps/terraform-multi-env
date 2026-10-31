# terraform-multi-env

Three AWS accounts (`dev`, `test`, `prod`). Three environments inside **each**
account (`env1`, `env2`, `env3`). Nine stacks in total, one reusable module.

The repo answers two questions:

1. How do I change a module for dev only, without touching test and prod?
2. How do I run many environments inside one AWS account without them
   colliding or overwriting each other's state?

## Layout

```
terraform-multi-env/
├── modules/                    # RESOURCE DEFINITIONS live here, nowhere else
│   ├── s3-bucket/              # the reusable building block
│   ├── security-groups/
│   ├── eks/                    # cluster, add-ons, node group, OIDC, Karpenter IAM
│   └── irsa/                   # IAM role for one k8s service account
│
├── live/
│   ├── dev/                    # = one AWS account
│   │   ├── account.tfvars      # values shared by every env in this account
│   │   ├── 02-eks/             # ACCOUNT-level layer: ONE shared EKS cluster
│   │   │   ├── main.tf         #   calls modules/eks, version PINNED here
│   │   │   ├── terraform.tfvars#   cluster_version, addon_versions  <-- upgrades
│   │   │   └── backend.hcl     #   its own state key: dev/02-eks/
│   │   ├── stack/              # the ROOT MODULE for every env in this account
│   │   │   ├── main.tf         #   <-- module version is PINNED here
│   │   │   ├── eks.tf          #   reads 02-eks outputs, builds this env's IRSA role
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── providers.tf
│   │   │   └── backend.tf      #   empty backend "s3" {} block
│   │   ├── env1/               # = one environment. Only 2 files.
│   │   │   ├── backend.hcl     #   its own state key
│   │   │   └── terraform.tfvars#   its own values
│   │   ├── env2/
│   │   └── env3/
│   ├── test/                   # same shape
│   └── prod/                   # same shape
│
├── bootstrap/                  # run once per ACCOUNT: state bucket + legacy lock table
├── scripts/tf.ps1              # Windows wrapper
├── scripts/tf.sh               # Linux / macOS / CI wrapper
├── .github/workflows/
├── docs/INTERVIEW_ANSWER.md
├── docs/EKS_UPGRADE_RUNBOOK.md # step-by-step, mapped to files in this repo
└── docs/APPLY_ENV1.html        # bootstrap -> 02-eks -> env1, with why + expected output
```

## Shared EKS: account layer vs environment layer

```
live/dev/
├── 02-eks/      ONE cluster, ONE state      owner: platform-team
└── stack/       run once per env            owner: app team
    + env1/      namespace env1, IRSA role demoapp-dev-env1-app, bucket
    + env2/      namespace env2, IRSA role demoapp-dev-env2-app, bucket
    + env3/      ...
```

| | shared (02-eks) | per env (stack + envN) |
|---|---|---|
| EKS cluster, nodes, OIDC, Karpenter IAM | yes | |
| Kubernetes namespace | | `env1`, `env2`, `env3` |
| IRSA role, S3 bucket | | yes |
| State file | `dev/02-eks/terraform.tfstate` | `dev/env1/app/terraform.tfstate` |

The env layer reads the cluster through `terraform_remote_state` and creates
only its own namespace-scoped pieces. An apply in env1 cannot break env2, and
neither can touch the cluster. Set `eks_enabled = true` in an env's tfvars
once `02-eks` has been applied for that account.

**The shape in one sentence:** one folder per account holds one stack and many
thin environment folders, and an environment folder contains nothing but its own
values and its own state pointer.

## State structure

Bootstrap keeps its state locally; it is not stored in the S3 buckets below.

```text
Local bootstrap state:
bootstrap/terraform.tfstate

S3 Bucket: demoapp-tfstate-dev-111111111111
S3-native locks: use_lockfile = true (.tflock object beside each state file)
DynamoDB table: demoapp-tflock-dev (legacy; not used for locking)
└── dev/
    ├── env1/
    │   └── app/terraform.tfstate
    ├── env2/
    │   └── app/terraform.tfstate
    └── env3/
        └── app/terraform.tfstate

S3 Bucket: demoapp-tfstate-test-222222222222
S3-native locks: use_lockfile = true (.tflock object beside each state file)
DynamoDB table: demoapp-tflock-test (legacy; not used for locking)
└── test/
    ├── env1/
    │   └── app/terraform.tfstate
    ├── env2/
    │   └── app/terraform.tfstate
    └── env3/
        └── app/terraform.tfstate

S3 Bucket: demoapp-tfstate-prod-333333333333
S3-native locks: use_lockfile = true (.tflock object beside each state file)
DynamoDB table: demoapp-tflock-prod (legacy; not used for locking)
└── prod/
    ├── env1/
    │   └── app/terraform.tfstate
    ├── env2/
    │   └── app/terraform.tfstate
    └── env3/
        └── app/terraform.tfstate
```

Each `backend.hcl` selects one bucket and one environment key. The account's
shared `stack/` uses that backend and combines `account.tfvars` with the selected
environment's `terraform.tfvars`. The wrapper stores its `.terraform` cache and
saved `tfplan` in the environment folder; those are not state files.

Bootstrap uses local state. When setting up another AWS account, use a separate
bootstrap working directory or state path; do not reuse
`bootstrap/terraform.tfstate` across dev, test, and prod.

## Why the stack is shared, not copied per environment

If every environment had its own full copy of `main.tf`, you would have nine
copies to keep in step. They drift apart within a month, and that drift is what
makes "it worked in test" stop being true.

So `env1/`, `env2/` and `env3/` contain **only two files each**. Everything
executable lives in `stack/`, once per account. If the folders look almost empty,
that is the design working.

## How the three isolation layers work here

### 1. Module version — pinned per account

`live/dev/stack/main.tf` pins the module version. `live/test/stack/main.tf` and
`live/prod/stack/main.tf` pin their own.

The stack source points to this repository's `modules/s3-bucket` folder at an
immutable Git tag. `v1.2.0` is the baseline; `v1.3.0` adds optional
`additional_tags`, which is empty by default and is enabled in dev only.

```hcl
# live/dev/stack/main.tf
source = "git::https://github.com/BhushDevOps/terraform-multi-env.git//modules/s3-bucket?ref=v1.3.0"

# live/test/stack/main.tf  and  live/prod/stack/main.tf
source = "git::https://github.com/BhushDevOps/terraform-multi-env.git//modules/s3-bucket?ref=v1.2.0"
```

The tag in `source` tells Terraform which repository snapshot to download.
Changing dev's ref to `v1.3.0` makes only the dev account load that module
version; test and prod still resolve `v1.2.0`, so their plan says
*No changes*. That empty plan is your proof to the reviewer.

The pin sits at the **account** level, not the environment level, and that is
deliberate: promotion between accounts is what you gate and review. If you need
one environment to try a version ahead of its siblings, give that environment its
own `stack/` folder temporarily, then fold it back once the version is promoted.

After changing a module ref, run `terraform init -upgrade` from that account's
`stack/` directory with the selected environment's `TF_DATA_DIR` and
`backend.hcl`. Terraform then downloads the pinned module version for that
environment. Plan and apply each environment separately; env1, env2, and env3
share the stack code but have independent state.

To release a later version, commit the module change, create a Git tag such as
`v1.4.0` on that commit, and push the tag. Then update the desired account's
`source` ref and plan its environments. Never move an existing version tag.

### 2. State — one bucket per account, one key per environment

```
s3://demoapp-tfstate-dev-111111111111/dev/env1/app/terraform.tfstate
s3://demoapp-tfstate-dev-111111111111/dev/env2/app/terraform.tfstate
s3://demoapp-tfstate-dev-111111111111/dev/env3/app/terraform.tfstate
```

The account is the security boundary, so the bucket belongs to the account. The
environments differ by **key**. Each backend uses Terraform's S3 lockfile
(`use_lockfile = true`), stored beside its state object. Locks are per state
file, so env1 and env2 never block each other. The bootstrap-created DynamoDB
tables are retained for now but are no longer referenced by the backends.

`backend.tf` holds an empty `backend "s3" {}` block. The real values come from
`live/<account>/<env>/backend.hcl` at init time. Nothing in the code can point a
dev run at prod state.

### 3. Account — credentials and a hard guard

Each account has its own IAM role, assumed via OIDC in CI. On top of that,
`providers.tf` sets:

```hcl
provider "aws" {
  allowed_account_ids = [var.account_id]
}
```

If your shell happens to hold prod credentials while you plan dev, Terraform
stops immediately instead of drawing you a plan against the wrong account.

## Name collisions — the thing that actually bites you

Three environments share one AWS account, so **every resource name must contain
the environment name**. Not just the account name.

```hcl
name_prefix = "${var.project}-${var.account_alias}-${var.env_name}"
# demoapp-dev-env1, demoapp-dev-env2, demoapp-dev-env3
```

Miss this and your second `terraform apply` fails with *BucketAlreadyExists*, or
worse, two environments quietly share one IAM role.

The rule: **account name alone is never a unique prefix.** It was enough when
one account held one environment. It is not enough now.

## Running it

### Once per AWS account

Creates the state bucket and legacy DynamoDB table. Uses local state; backends
now use S3-native lockfiles, so the DynamoDB table is not used for locking.

```powershell
cd bootstrap
terraform init
terraform apply -var="project=demoapp" -var="account_alias=dev" -var="account_id=111111111111"
```

Repeat in the test and prod accounts.

### Normal work

Run Terraform directly from the account's `stack/` directory. For dev env1,
from the repository root:

```powershell
Set-Location live/dev/stack
$env:TF_DATA_DIR = (Join-Path (Resolve-Path ..\env1).Path '.terraform')
terraform init -reconfigure -backend-config=..\env1\backend.hcl
terraform plan `
    -var-file=..\account.tfvars `
    -var-file=..\env1\terraform.tfvars `
    -out=..\env1\tfplan
terraform apply ..\env1\tfplan
```

The Terraform files are in `stack/`, so running `terraform init` from
`live/dev/` itself will not select the root module. To operate on env2 or env3,
change every `env1` path above to the selected environment and set
`TF_DATA_DIR` to that environment's `.terraform` directory before running
`init`. Keep the `TF_DATA_DIR` value set through plan and apply, and review the
plan before applying it.

### What to specify for each direct run

Because all environments in an account share one `stack/` folder, every direct
run needs these three environment-specific inputs:

| Thing | Where it comes from |
|---|---|
| which backend to init with | `live/<acct>/<env>/backend.hcl` |
| which values to use | `account.tfvars` then `<env>/terraform.tfvars` |
| where to keep `.terraform` | `TF_DATA_DIR=../<env>/.terraform` |

The separate `TF_DATA_DIR` is essential. Without it, env1 and env2 share one
`.terraform` folder and cached backend pointer. Keep each saved plan in its
environment folder as shown above; do not apply one environment's plan to
another environment.

## Two layers of values

`account.tfvars` loads first, the environment's `terraform.tfvars` loads second,
and **the later file wins**. So an environment can override any account default:

```hcl
# live/prod/account.tfvars
region = "ap-south-1"

# live/prod/env2/terraform.tfvars   (production - Europe)
region = "eu-west-1"     # this one wins
```

Note that `prod/env2`'s *resources* move to `eu-west-1` while its *state* stays
in the account's `ap-south-1` bucket. Backend region and provider region are two
different settings.

## What each environment is for

| Account | env1 | env2 | env3 |
|---|---|---|---|
| **dev** | shared team sandbox | feature branch testing | integration / QA |
| **test** | functional test | performance test | UAT / pre-production |
| **prod** | production India | production Europe | disaster recovery |

Settings that follow from that:

| Setting | dev | test | prod |
|---|---|---|---|
| Versioning | off | on | on |
| `force_destroy` | true | true (env3 false) | **false** |
| Old version cleanup | off / 7d | 30d / 90d | 365d |

Same module everywhere. Only the values differ.

## CI

`.github/workflows/terraform.yml` plans all nine stacks on a pull request as a
`3 x 3` matrix, so the reviewer sees every plan and can confirm that only the
intended ones are non-empty.

On merge it calls `apply-account.yml` three times with `needs:` between them, so
accounts apply in order — dev, then test, then prod — while the three
environments inside an account apply in parallel. Required reviewers on the
`prod-*` GitHub Environments turn the prod step into a gated release.

## Trying the isolation yourself

1. `additional_tags` is an optional v1.3.0 input with an empty default.
2. Dev sets `module-version = "1.3.0"`, so its plan shows the bucket tag change.
3. Test and prod load v1.2.0 and do not receive the new input.
4. Each dev environment uses the same module version but has separate state.

## Scaling further

**More environments?** Copy an env folder, change `env_name` and the state key.
Two files. Nothing else.

**More resource types (ECS, EC2, RDS)?** Split each environment's stack into
layers so one change does not plan everything and a broken compute change cannot
damage the network:

```
live/prod/
├── stack-00-network/
├── stack-10-data/
├── stack-20-compute/
└── stack-30-services/
```

Each layer gets its own state key (`prod/env1/network/terraform.tfstate`) and
reads the layer below it through `terraform_remote_state` outputs.

**Tired of the wrapper script?** That wrapper is roughly what Terragrunt does for
you. Moving to Terragrunt is a reasonable next step once you have more than a
dozen stacks — say so in an interview and you will sound like someone who has
lived with this.

See `docs/INTERVIEW_ANSWER.md` for the spoken answer, the anti-patterns, and the
likely follow-up questions.
