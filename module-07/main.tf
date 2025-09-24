# Terraform for Module 07
##############################################################################
# You will need to fill in the blank values using the values in terraform.tfvars
# or using the links to the documentation. You can also make use of the auto-complete
# in VSCode
# Reference your code in Module 04 to fill out the values
# This is the same exercise but converting from Bash to HCL
##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs
##############################################################################
data "aws_vpc" "main" {
  default = true
}

output "vpcs" {
  value = data.aws_vpc.main.id
}
##############################################################################
# https://developer.hashicorp.com/terraform/tutorials/configuration-language/data-source
##############################################################################
data "aws_availability_zones" "available" {
  state = "available"
  /*
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
*/
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones
##############################################################################
data "aws_availability_zones" "primary" {
  filter {
    name   = "zone-name"
    values = ["ap-south-1a"]
  }
}

data "aws_availability_zones" "secondary" {
  filter {
    name   = "zone-name"
    values = ["ap-south-1b"]
  }
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets
##############################################################################
# The data value is essentially a query and or a filter to retrieve values
data "aws_subnets" "subneta" {
  filter {
    name   = "availabilityZone"
    values = ["ap-south-1a"]
  }
}

data "aws_subnets" "subnetb" {
  filter {
    name   = "availabilityZone"
    values = ["ap-south-1b"]
  }
}

data "aws_subnets" "subnetc" {
  filter {
    name   = "availabilityZone"
    values = ["ap-south-1c"]
  }
}

output "subnetid-2a" {
  value = [data.aws_subnets.subneta.ids]
}

output "subnetid-2b" {
  value = [data.aws_subnets.subnetb.ids]
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
##############################################################################
resource "aws_lb" "lb" {
  name               = var.elb-name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.vpc_security_group_ids]

  subnets = [data.aws_subnets.subneta.ids[0], data.aws_subnets.subnetb.ids[0]]
  
  enable_deletion_protection = false

  tags = {
    Environment = var.module-tag
  }
}

# output will print a value out to the screen
output "url" {
  value = aws_lb.lb.dns_name
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
##############################################################################

resource "aws_lb_target_group" "alb-lb-tg" {
  # depends_on is effectively a waiter -- it forces this resource to wait until the listed
  # resource is ready
  depends_on  = [aws_lb.lb]
  name        = var.tg-name
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
##############################################################################

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-lb-tg.arn
  }
}

##############################################################################
# Create launch template
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/launch_template
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template
##############################################################################
resource "aws_launch_template" "mp1-lt" {
  image_id                             = var.imageid
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance-type
  key_name                             = var.key-name

  monitoring {
    enabled = false
  }
  placement {
    availability_zone = data.aws_availability_zones.primary.id
  }
  
  block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size = 15
    }
  }

  block_device_mappings {
    device_name = "/dev/sdg"

    ebs {
      volume_size = 15
    }
  }

  network_interfaces {
  subnet_id = data.aws_subnets.subneta.ids[0]
  security_groups = [var.vpc_security_group_ids]
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.module-tag
    }
  }
  user_data = filebase64(var.install-env-file)
}

##############################################################################
# Create autoscaling group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group
##############################################################################

 # DON'T USE "target_group_arns"  attribute if you want to create "aws_autoscaling_attachment" resource.
 # This gives race condition beacuse we are trying same thing twice!
 # Use only one way. Not both!

resource "aws_autoscaling_group" "bar" {
  name                      = var.asg-name
  depends_on                = [aws_launch_template.mp1-lt]
  desired_capacity          = var.desired
  max_size                  = var.max
  min_size                  = var.min
  health_check_grace_period = 300
  health_check_type         = "ELB"
  vpc_zone_identifier       = [data.aws_subnets.subneta.ids[0], data.aws_subnets.subnetb.ids[0]]

  tag {
    key                 = "module"
    value               = var.module-tag
    propagate_at_launch = true  # enables propagation of tags to ec2 instances via this ASG
  }

  launch_template {
    id      = aws_launch_template.mp1-lt.id
    version = "$Latest"
  }
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment
##############################################################################
# Create a new ALB Target Group attachment

resource "aws_autoscaling_attachment" "example" {
  # Wait for lb to be running before attaching to asg
  depends_on  = [aws_lb.lb]
  autoscaling_group_name = aws_autoscaling_group.bar.name
  lb_target_group_arn    = aws_lb_target_group.alb-lb-tg.arn
}

output "alb-lb-tg-arn" {
  value = aws_lb_target_group.alb-lb-tg.arn
}

output "alb-lb-tg-id" {
  value = aws_lb_target_group.alb-lb-tg.id
}