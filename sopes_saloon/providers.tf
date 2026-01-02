provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region
}

provider "aws" {
    alias = "security"
    region = var.region
    assume_role {
      role_arn = var.security_role_arn
    }
}