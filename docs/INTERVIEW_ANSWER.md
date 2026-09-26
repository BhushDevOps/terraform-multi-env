# The interview answer

**Question:** You have a DEV AWS account, a TEST account and a PROD account.
Each account contains several environments (env1, env2, env3). You have ECS,
EC2, S3 and application code. How do you structure the repository so that a
change to the S3 bucket module can be tested in dev without changing test or
prod?

---

## Short answer (say this first)

> Two repositories: a Terraform repo and an application repo.
>
> Inside the Terraform repo I have `modules/` and `live/`. `live/` has one
> folder per **AWS account**, and inside each account one folder per
> **environment**. The account folder holds the root module — that is where the
> module version is pinned. The environment folders are thin: just a tfvars file
> and a backend config.
>
> So there are three levels: module, account, environment. A module change is
> tagged, then the pin is bumped in the dev account only. Test and prod still
> resolve the old tag, so their plan is empty — that empty plan is what I show
> the reviewer.
>
> Inside one account the environments stay apart in two ways: every resource
> name carries the environment name, and every environment has its own state
> key in the account's state bucket.

Then walk through the layout below.

---

## 1. The layout

```
terraform/                      <- repo 1
├── modules/
│   ├── s3-bucket/
│   ├── ecs-service/
│   └── ec2-asg/
└── live/
    ├── dev/                    <- AWS account 111111111111
    │   ├── account.tfvars      <- values shared by every env here
    │   ├── stack/              <- ROOT MODULE, module version pinned here
    │   ├── env1/               <- backend.hcl + terraform.tfvars  (2 files)
    │   ├── env2/
    │   └── env3/
    ├── test/                   <- AWS account 222222222222
    └── prod/                   <- AWS account 333333333333

app/                            <- repo 2: source code, Dockerfile, its own CI
```

Three levels, three jobs:

| Level | Holds | Changes when |
|---|---|---|
| `modules/` | how a thing is built | you improve the building block |
| `live/<account>/stack/` | which module version, wired together | you promote a version |
| `live/<account>/<env>/` | values only | you tune one environment |

**Why the environment folders are nearly empty.** If all nine environments had a
full copy of `main.tf`, you would have nine copies to keep in step, and they
drift. Sharing one stack per account means an environment cannot accidentally be
different in structure — only in values.

## 2. How the S3 module change flows

1. Branch, change `modules/s3-bucket`. Keep it **backward compatible**: new
   optional variable, default preserves old behaviour.
2. Merge and tag `v1.3.0`.
3. One pull request that edits a single line in `live/dev/stack/main.tf`:
   `?ref=v1.2.0` becomes `?ref=v1.3.0`.
4. CI plans all nine stacks. The three dev stacks show the change. The six test
   and prod stacks show **No changes**.
5. Apply dev. Soak it. Then a second PR bumps test. Then a third bumps prod,
   with a required reviewer.

**If they ask why the pin is per account and not per environment:** because
promotion between accounts is the thing you gate and review, and env1/env2/env3
inside dev are meant to be identical copies. If I genuinely need one environment
to run ahead of its siblings, I give it its own `stack/` folder for the duration
of the test, then fold it back.

## 3. Keeping environments apart inside one account

This is the part the question is really testing. Two separate problems.

### Problem A — name collisions

Three environments in one account means one namespace. Every resource name must
contain the environment name, not just the account name:

```hcl
name_prefix = "${var.project}-${var.account_alias}-${var.env_name}"
# demoapp-dev-env1 / demoapp-dev-env2 / demoapp-dev-env3
```

Miss this and the second apply fails with *BucketAlreadyExists*, or two
environments quietly share one IAM role. **The account name alone is not a
unique prefix any more.**

### Problem B — state separation

One state bucket per account, one key per environment:

```
s3://demoapp-tfstate-dev-111111111111/dev/env1/app/terraform.tfstate
s3://demoapp-tfstate-dev-111111111111/dev/env2/app/terraform.tfstate
```

The bucket belongs to the account because the account is the security boundary.
The environments differ by key. One DynamoDB lock table per account is enough —
locks are per state file, so env1 and env2 never block each other.

`backend.tf` has an empty `backend "s3" {}` block; the values come from each
environment's `backend.hcl` at init time.

### Plus the guard rail

```hcl
provider "aws" {
  allowed_account_ids = [var.account_id]
}
```

If your shell holds prod credentials while you plan dev, Terraform refuses
instead of drawing a plan against the wrong account.

## 4. The operational detail that shows experience

All environments in an account share one `stack/` folder, so a run must be told
which environment it is. Three things per run:

```bash
cd live/dev/stack
export TF_DATA_DIR=../env1/.terraform          # <- the important one
terraform init -reconfigure -backend-config=../env1/backend.hcl
terraform plan -var-file=../account.tfvars -var-file=../env1/terraform.tfvars -out=../env1/tfplan
```

Without a per-environment `TF_DATA_DIR`, env1 and env2 share one `.terraform`
folder and one cached backend pointer, and you can apply env1's saved plan onto
env2's state. I wrap this in a script so nobody has to remember it:
`./scripts/tf.sh dev env1 plan`.

Mentioning this unprompted is a strong signal. It is the exact bug people hit in
month two of running this layout.

**And then say:** that wrapper is essentially what Terragrunt does natively.
Past a dozen or so stacks I would move to Terragrunt rather than grow the script.

## 5. Why two repos and not three

The application repo must be separate — that is the split that matters.
Application code deploys many times a day, infrastructure changes a few times a
month. Same repo means every app commit triggers a Terraform plan, and a broken
plan blocks a hotfix. Terraform only holds the ECS task definition and takes
`image_tag` as a variable.

Splitting `modules/` into a **third** repo is an organisational decision, not a
technical one. Do it when:

- more than one team consumes the modules, so no single `live` repo can own them;
- app teams need read access to modules but must not see production live code;
- the shared git tag namespace becomes confusing, because a tag covers the whole
  repo including your prod tfvars;
- module CI (lint, validate, terratest) and live CI (plan against real AWS)
  start getting in each other's way.

Until then, two repos with tags on the Terraform repo is simpler and gives the
exact same isolation.

## 6. What NOT to say

| Avoid | Why interviewers dislike it |
|---|---|
| "`terraform workspace` for dev/test/prod" | One backend and one credential set for all three accounts. Easy to hit prod by accident |
| "`terraform workspace` for env1/env2/env3" | Defensible — same account, same credentials, same backend. But the state keys become invisible in the folder structure, and a forgotten `workspace select` applies to the wrong environment. Explicit folders are safer. Know the trade-off, then still choose folders |
| "Local module path in every environment" | One edit changes all nine environments at once. That is the problem in the question |
| "A copy of the module per environment" | Nine copies that drift apart in a month |
| "A branch per environment" | Merges become the release process, cherry picks go wrong, prod quietly falls behind |
| "One state file for everything" | Slow plans, one lock for the whole company, one mistake destroys unrelated resources |
| "One state bucket for all three accounts" | Cross account access just to read state, and dev credentials with a path to prod state |

## 7. Likely follow-ups and short answers

**How do you add env4?**
Copy an env folder, change `env_name` and the state key. Two files. That is the
test of whether the structure is right.

**ECS, EC2 and RDS in the same stack?**
No. Split each environment into layers with their own state:
`stack-00-network`, `stack-10-data`, `stack-20-compute`, `stack-30-services`.
Higher layers read lower ones with `terraform_remote_state`. Keeps plans fast and
limits blast radius.

**How does the application get deployed then?**
App CI builds the image and pushes to ECR with an immutable tag. Either Terraform
takes `image_tag` as a variable, or a separate deploy step updates the ECS
service. Infrastructure and application must not block each other.

**Drift?**
Nightly pipeline running `terraform plan -detailed-exitcode` on all nine stacks,
alert on exit code 2. Plus `prevent_destroy` on state and data resources.

**Module testing?**
`terraform fmt`, `validate`, `tflint`, `checkov`/`tfsec` on PR, then `terratest`
or the native `terraform test` creating a real bucket in a sandbox account and
destroying it after.

**Secrets?**
Never in tfvars. Secrets Manager or SSM Parameter Store read via data source,
OIDC for CI credentials so there are no static keys anywhere.

**How do you stop environments drifting apart?**
Same stack, same module, only tfvars differ. Any difference has to be expressed
as a variable — never as extra resources in one environment's copy of the code.
