provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}
