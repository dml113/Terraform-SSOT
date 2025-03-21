terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }

  backend "s3" {
    bucket         = "lee-0410-tfstate"
    key            = "terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

################################################################################################################################################
#                                                                 VPC                                                                          #
################################################################################################################################################

module "vpc" {
    source  = "terraform-aws-modules/vpc/aws"

    name            = "my-vpc"
    cidr            = "10.0.0.0/16"
    azs             = ["ap-northeast-1a", "ap-northeast-1c"]

    public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
    public_subnet_names = ["my-public-subnet-a" , "my-public-subnet-c"]
    map_public_ip_on_launch = true
    public_subnet_tags = {
      "kubernetes.io/role/elb" = 1
    }

    enable_dns_hostnames = true
    enable_dns_support   = true
}

################################################################################################################################################
#                                                                 EC2                                                                          #
################################################################################################################################################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }
}


resource "aws_security_group" "httpd_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "httpd" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.small"
  subnet_id             = module.vpc.public_subnets[0]
  security_groups       = [aws_security_group.httpd_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              echo "<html><head><title>Welcome</title><style>body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background-color: #f4f4f4; } h1 { color: #333; font-size: 3em; } </style></head><body><h1>Hello, Tokyo Region</h1></body></html>" > /var/www/html/index.html
              systemctl enable httpd
              systemctl start httpd
              EOF

  tags = {
    Name = "httpd-server"
  }
}
