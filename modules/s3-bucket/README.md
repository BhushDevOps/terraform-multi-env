# Module: s3-bucket

Creates one S3 bucket with encryption, versioning, public access block and an optional lifecycle rule.

## Why this module has its own version

Every environment points at this module with a **pinned version** (a git tag).
Dev can move to a new tag while test and prod stay on the old one. That is how
you change the module for dev only.

```hcl
module "app_bucket" {
  source = "git::https://github.com/<org>/terraform-modules.git//modules/s3-bucket?ref=v1.3.0"
}
```

## Inputs

| Name | Type | Default | What it does |
|---|---|---|---|
| `bucket_name` | string | required | Bucket name, must be globally unique |
| `force_destroy` | bool | `false` | Let Terraform delete a non-empty bucket. Keep `false` in prod |
| `versioning_enabled` | bool | `true` | Keeps old copies of objects |
| `sse_algorithm` | string | `AES256` | `AES256` or `aws:kms` |
| `kms_key_arn` | string | `null` | Used only when `sse_algorithm = "aws:kms"` |
| `block_public_access` | bool | `true` | Blocks all public access |
| `lifecycle_expiration_days` | number | `0` | Deletes old versions after N days. `0` turns the rule off |
| `tags` | map(string) | `{}` | Tags for the bucket |

## Outputs

| Name | What it gives you |
|---|---|
| `bucket_id` | The bucket name |
| `bucket_arn` | The bucket ARN |
| `bucket_domain_name` | Regional domain name |

## Rules for changing this module

1. Never break an existing input. Add a new optional variable with a default instead.
2. New behaviour must be **off by default**, so old environments do not change on upgrade.
3. Tag a new version after merge. Bump dev first, then test, then prod.
