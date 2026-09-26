# Empty on purpose. The real values arrive at init time from the ENV folder:
#   terraform -chdir=live/<account>/stack init -backend-config=../<env>/backend.hcl
#
# One state BUCKET per AWS account, one state KEY per environment inside it.
terraform {
  backend "s3" {}
}
