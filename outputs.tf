data "aws_instance" "management" {
  instance_id = aws_instance.management_host.id
  #  instance_id = module.management_ec2.instance_id[0]
}

output "management_ec2_public_ip" {
  description = "The public IP of the management EC2 instance."
  value       = data.aws_instance.management.public_ip
}

output "application_load_balancer_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = module.alb.lb_dns_name
}
