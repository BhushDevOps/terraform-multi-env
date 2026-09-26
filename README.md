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
├── modules/
│   └── s3-bucket/              # the reusable building block
│
├── live/
│   ├── dev/                    # = one AWS account
│   │   ├── account.tfvars      # values shared by every env in this account
│   │   ├── stack/              # the ROOT MODULE for this account
│   │   │   ├── main.tf         #   <-- module version is PINNED here
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
├── bootstrap/                  # run once per ACCOUNT: state bucket + lock table
├── scripts/tf.ps1              # Windows wrapper
├── scripts/tf.sh               # Linux / macOS / CI wrapper
├── .github/workflows/
└── docs/INTERVIEW_ANSWER.md
```

**The shape in one sentence:** one folder per account holds one stack and many
thin environment folders, and an environment folder contains nothing but its own
values and its own state pointer.

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

Run `plan` through the wrapper after changing the module ref. It runs `init`
using a separate `TF_DATA_DIR` for that environment, downloads the pinned
module version, then plans against that environment's backend and variables.
Apply only after reviewing the plan:

```powershell
.\scripts\tf.ps1 dev env1 plan
.\scripts\tf.ps1 dev env1 apply
```

Repeat for `dev env2` and `dev env3` when ready; they share the dev stack code,
but each has its own state and must be planned and applied separately.

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
environments differ by **key**. One DynamoDB lock table per account is enough —
the lock is per state file, so env1 and env2 never block each other.

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

Creates the state bucket and lock table. Uses local state.

```powershell
cd bootstrap
terraform init
terraform apply -var="project=demoapp" -var="account_alias=dev" -var="account_id=111111111111"
```

Repeat in the test and prod accounts.

### Normal work

```powershell
.\scripts\tf.ps1 dev  env1 plan
.\scripts\tf.ps1 dev  env1 apply

.\scripts\tf.ps1 prod env2 plan
```

Linux, macOS or CI:

```bash
./scripts/tf.sh dev env1 plan
./scripts/tf.sh dev env1 apply
```

### What the wrapper does, and why you need one

Because all environments in an account share one `stack/` folder, every run must
be told three things:

| Thing | Where it comes from |
|---|---|
| which backend to init with | `live/<acct>/<env>/backend.hcl` |
| which values to use | `account.tfvars` then `<env>/terraform.tfvars` |
| where to keep `.terraform` | `TF_DATA_DIR=../<env>/.terraform` |

The third one is the dangerous one. Without a separate `TF_DATA_DIR`, env1 and
env2 share one `.terraform` folder and one cached backend pointer — and you can
apply env1's saved plan onto env2's state. The wrapper makes that impossible.

Raw commands, if you want to see what the wrapper runs:

```bash
cd live/dev/stack
export TF_DATA_DIR=../env1/.terraform
terraform init -reconfigure -backend-config=../env1/backend.hcl
terraform plan -var-file=../account.tfvars -var-file=../env1/terraform.tfvars -out=../env1/tfplan
terraform apply ../env1/tfplan
```

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
