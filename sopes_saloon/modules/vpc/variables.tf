variable "region" {
  type = string
}

variable "environment" {
    type = string
  default = "dev"
}

variable "network_info" {
  description = "A map of networking configuration values for the VPC and subnets"
  type = object({
    vpc_name             = string
    vpc_cidr             = string
    public_subnets       = map(string)
    map_public_ip        = optional(bool, true)
    enable_dns_hostnames = optional(bool, true)
    enable_dns_support   = optional(bool, true)
  })
}
