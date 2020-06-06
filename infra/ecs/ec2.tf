# resource "aws_autoscaling_group" "dockerzon-cluster-asg" {
#   name                      = "DockerzonClusterASG"
#   max_size                  = var.max_size_asg
#   min_size                  = var.min_size_asg
#   desired_capacity          = var.desired_capacity_asg
#   vpc_zone_identifier       = data.aws_subnet_ids.dockerzon-public-subnets.ids
#   target_group_arns         = [aws_lb_target_group.dockerzon-lb-tg-temperature-api.arn]
#   health_check_type         = "EC2"
#   health_check_grace_period = 300
#   service_linked_role_arn   = data.terraform_remote_state.prerequisites-state.outputs.autoscaling-service-linked-role-arn

#   launch_template {
#     id      = aws_launch_template.dockerzon-asg.id
#     version = "$Latest"
#   }
# }

resource "aws_cloudformation_stack" "dockerzon-cluster-asg" {
  name = "${var.cfn_stack_name}"

  parameters = {
    vpc_zone_identifier     = data.aws_subnet_ids.dockerzon-public-subnets.ids
    launch_template_id      = aws_launch_template.dockerzon-asg.id
    min_size                = var.min_size_asg
    max_size                = var.max_size_asg
    desired_capacity        = var.desired_capacity_asg
    target_group_arns       = [aws_lb_target_group.dockerzon-lb-tg-temperature-api.arn]
    service_linked_role_arn = data.terraform_remote_state.prerequisites-state.outputs.autoscaling-service-linked-role-arn
  }

  template_body = file("${path.module}/configs/asg_template.yml")

  # create a new one before destroy old one when a resource must be re-created upon a requested change
  lifecycle {
    create_before_destroy = true
  }
}

# launch template
resource "aws_launch_template" "dockerzon-asg" {
  name = "${var.app_name}-asg-launch-template"

  image_id      = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      delete_on_termination = true
      volume_type           = "gp2"
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    description                 = "dockerzon ECS instance ENI"
    device_index                = 0
    security_groups             = data.aws_security_groups.app-sg.ids
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.instance-profile.name
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Origin = "Lauched by Dockerzon ASG launch template"
      Name   = "${var.app_name}-asg"
    }
  }

  user_data = base64encode(templatefile("configs/index.sh", { cluster = var.cluster, attribute = var.instance_attributes }))
}
