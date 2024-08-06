terraform {
  backend "s3" {
    bucket         = "yeyo-terraform-state-bucket"
    key            = "terraform/state"
    region         = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.12.0"

  name = "yeyo-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "web" {
  count = 2

  ami           = "ami-0ba9883b710b05ac6" # Amazon Linux 2023
  instance_type = "t2.micro"

  subnet_id = element(module.vpc.public_subnets, count.index)

  tags = {
    Name = "WebServer-${count.index}"
  }
}

resource "aws_elb" "web" {
  name               = "web-load-balancer"
  subnets            = module.vpc.public_subnets

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances = aws_instance.web[*].id

  tags = {
    Name = "web-load-balancer"
  }
}
