
## Networking Resources
module "prod_vpc" {
  source       = "./modules/vpc"
  environment  = var.environment
  region       = var.region
  network_info = var.network_info
}

## EC2 Resources

resource "aws_security_group" "main" {
  name   = "sopes-saloon-sg"
  vpc_id = module.prod_vpc.vpc_id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ssm_parameter" "amzn2_linux" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

resource "aws_instance" "web" {
  ami                         = nonsensitive(data.aws_ssm_parameter.amzn2_linux.value)
  instance_type               = var.instance_type
  subnet_id                   = module.prod_vpc.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.main.id]
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/templates/user_data.sh",
    {
      environment = var.environment
  })

  tags = {
    Name = "nacho-brigade-web-${var.environment}"
  }
}

## S3 Resources

resource "random_string" "bucket_suffix" {
  length  = 12
  upper   = false
  special = false
}


module "prod_s3_bucket" {
  source = "../vpc_flow_logs"
  vpc_id = module.prod_vpc.vpc_id
  naming_prefix = "sopes-saloon"
  iam_role_arn = var.security_role_arn
  bucket_id_suffix = random_string.bucket_suffix.result

  providers = {
    aws.vpc_account = aws
    aws = aws.security
  }
}