output "public_subnet_ids" {
  description = "The list of IDs for the public subnets created in the VPC"
  value       = module.prod_vpc.public_subnet_ids
}

output "vpc_id" {
  description = "The ID of the VPC created"
  value       = module.prod_vpc.vpc_id
}

output "public_dns" {
  description = "The public DNS name of the web server instance"
  value       = aws_instance.web.public_dns
}
