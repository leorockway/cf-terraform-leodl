# Use versions.tf for provider config, not here
provider "aws" {
  region = var.aws_region
}

# VPC and Subnets
module "vpc" {
  source = "github.com/Coalfire-CF/terraform-aws-vpc-nfw"
  name = "my-project-vpc"
  cidr = "10.1.0.0/16"
  flow_log_destination_type = "cloud-watch-logs"

  enable_nat_gateway = true
  
  azs = [
    var.aws_region_az1,
    var.aws_region_az2
  ]

  public_subnets = ["10.1.1.0/24", "10.1.4.0/24"]
  public_subnet_tags =  {
    "0" = "Management"
    "1" = "Public-ALB" # This second public subnet is required by the ALB
  }

  private_subnets = ["10.1.2.0/24", "10.1.3.0/24"]
    private_subnet_tags = { #please note this goes alphabetically in order
    "0" = "App"
    "1" = "Backend"
  }
}


# Security Groups
module "management_sg" {
  source = "github.com/Coalfire-CF/terraform-aws-securitygroup?ref=v1.0.1"
  vpc_id = module.vpc.vpc_id
  name   = "management-sg"
  description = "Allows SSH from a specific IP"
  ingress_rules = {
    "allows ssh" = {
      from_port   = 22
      to_port     = 22
      ip_protocol    = "tcp"
      cidr_ipv4 = var.allowed_ssh_ip
      description = "Allow SSH"
    }
  }
}

module "application_sg" {
  source = "github.com/Coalfire-CF/terraform-aws-securitygroup?ref=v1.0.1"
  vpc_id = module.vpc.vpc_id
  name   = "application-sg"
  description = "Allows SSH from management and web traffic from ALB"
  ingress_rules = {
    "allows ssh" = {
      from_port = 22
      to_port = 22
      ip_protocol = "tcp"
      referenced_security_group_id = module.management_sg.id
      description = "Allow SSH from management"
    },
    "allows http" = {
      from_port = 80
      to_port = 80
      ip_protocol = "tcp"
      referenced_security_group_id = module.alb_sg.id
      description = "Allow web traffic from ALB"
    }
  }

  egress_rules = {
    "allows all egress" = {
      from_port = 0
      to_port = 0
      ip_protocol = "-1"
      cidr_ipv4 = "0.0.0.0/0"
      description = "Allow all outbound traffic"
    }
  }
}

# This doesn't work, for some reason it's not passing the ec2_key_pair
# # Management EC2
# module "management_ec2" {
#   source           = "github.com/Coalfire-CF/terraform-aws-ec2.git"
#   name             = "management-host" 
#   associate_public_ip = true
#   ec2_key_pair     = var.ec2_key_pair
#   ec2_instance_type = "t3.micro"
#   ami              = "ami-0c55b159cbfafe1f0"
#   vpc_id           = module.vpc.vpc_id
#   subnet_ids = values(module.vpc.public_subnets)
#   root_volume_size = 8
#   global_tags = {
#     "managed_by" = "terraform"
#     "purpose"    = "management"
#   }
#   additional_security_groups = [module.management_sg.id]
#   ebs_kms_key_arn = ""
#   ebs_optimized = true
# }

# Management EC2
resource "aws_instance" "management_host" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  key_name      = var.ec2_key_pair
  subnet_id                   = values(module.vpc.public_subnets)["0"]
  associate_public_ip_address = true
  vpc_security_group_ids = [module.management_sg.id]

  tags = {
    Name = "management-host"
    managed_by = "terraform"
    purpose    = "management"
  } 
}


# Application Load Balancer
module "alb" {
  source             = "terraform-aws-modules/alb/aws"
  version            = "8.7.0"
  name               = "application-alb"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id

  subnets = values(module.vpc.public_subnets)

  security_groups = [
    module.alb_sg.id
  ]

  target_groups = [
    {
      name_prefix      = "apptg-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      health_check = {
        path = "/"
        port = "traffic-port"
      }
    }
  ]

  http_tcp_listeners = [
    {
      port              = 80
      protocol          = "HTTP"
      target_group_index = 0
    }
  ]
}

# ASG and Launch Template
module "autoscaling" {
  source = "terraform-aws-modules/autoscaling/aws"
  version = "7.3.1"
  name    = "application-asg"

  vpc_zone_identifier = values(module.vpc.private_subnets)

  min_size          = 2
  max_size          = 6
  desired_capacity  = 2
  
  launch_template_name = "application-lt"
  image_id             = "ami-0c55b159cbfafe1f0"
  instance_type        = "t3.micro"
  user_data            = base64encode(file("install_apache.sh"))

  network_interfaces = [
    {
      device_index    = 0
      security_groups = [module.application_sg.id]
    }
  ]

  target_group_arns = [module.alb.target_group_arns[0]]
}

# Security Group for the ALB
module "alb_sg" {
  source = "github.com/Coalfire-CF/terraform-aws-securitygroup?ref=v1.0.1"
  vpc_id = module.vpc.vpc_id
  name   = "alb-sg"
  description = "Allows HTTP from the internet"
  ingress_rules = {
    "allows http" = {
      from_port = 80
      to_port = 80
      ip_protocol = "tcp"
      cidr_ipv4 = "0.0.0.0/0"
      description = "Allow HTTP from internet"
    }
  }
  
  egress_rules = {
    "allows all egress" = {
      from_port = 0
      to_port = 0
      ip_protocol = "-1"
      cidr_ipv4 = "0.0.0.0/0"
      description = "Allow all outbound traffic"
    }
  }
}
