# Empty on purpose. The real values come from ./backend.hcl:
#   terraform -chdir=live/prod/02-eks init -backend-config=backend.hcl
#
# Same state BUCKET as the env stacks, its own KEY: prod/02-eks/terraform.tfstate
terraform {
  backend "s3" {}
}
