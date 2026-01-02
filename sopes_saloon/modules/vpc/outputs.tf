output "public_subnet_ids" {
  description = "The list of IDs for the public subnets created in the VPC"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "vpc_id" {
  description = "The ID of the VPC created"
  value       = aws_vpc.main.id
}
