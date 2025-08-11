variable "private_subnet_tags" {
  description = "List of tags for private subnets."
  type        = list(string)
  default     = ["private1", "private2"]
}

variable "aws_region" {
  description = "The AWS region to deploy into."
  type        = string
}

variable "aws_region_az1" {
  description = "First availability zone for the region."
  type        = string
}

variable "aws_region_az2" {
  description = "Second availability zone for the region."
  type        = string
}

variable "allowed_ssh_ip" {
  description = "The IP address or CIDR block allowed to SSH into the management host."
  type        = string
}

variable "ec2_key_pair" {
  description = "The name of the EC2 key pair to use"
  type        = string
  default = "cf"
}
