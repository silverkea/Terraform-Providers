## Networking Resources
module "dr_vpc" {
  source       = "./modules/vpc"
  environment  = var.environment
  region       = var.dr_region
  network_info = var.network_info

  providers = {
    aws = aws.dr
  }
}