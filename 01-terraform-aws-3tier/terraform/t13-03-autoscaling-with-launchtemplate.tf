# Please check the following source for the original source code
# https://github.com/terraform-aws-modules/terraform-aws-autoscaling/blob/v6.5.0/examples/complete/main.tf

module "autoscaling" {
  depends_on = [module.vpc, module.alb]
  source     = "terraform-aws-modules/autoscaling/aws"
  version    = "6.5.0"

  # Autoscaling group
  name            = "${local.name}-my-asg"
  use_name_prefix = false
  instance_name   = "${var.environment}-my-instance"

  # ignore_desired_capacity_changes = true # need to change?

  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = module.vpc.private_subnets
  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn

  initial_lifecycle_hooks = [
    {
      name                 = "ExampleStartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 60
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                 = "ExampleTerminationLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 180
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
    }
    triggers = ["tag", "desired_capacity"] # Desired Capacity here added for demostrating the Instance Refresh scenario
  }

  # Launch template
  launch_template_name        = "${local.name}-complete"
  launch_template_description = "Complete launch template example"
  update_default_version      = true

  image_id          = data.aws_ami.amzlinux2.id
  instance_type     = var.instance_type
  key_name          = var.instance_keypair
  user_data         = filebase64("${path.module}/app1-install.sh")
  ebs_optimized     = true
  enable_monitoring = true

  # iam_instance_profile_arn = aws_iam_instance_profile.ssm.arn
  create_iam_instance_profile = true
  iam_role_name               = "${local.name}-complete"
  iam_role_path               = "/ec2/"
  iam_role_description        = "Complete IAM role example"
  iam_role_tags = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Security group is set on the ENIs below
  security_groups = [module.private_sg.security_group_id]

  target_group_arns = module.alb.target_group_arns

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 20
        volume_type           = "gp2"
      }
      }, {
      device_name = "/dev/sda1"
      no_device   = 1
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 30
        volume_type           = "gp2"
      }
    }
  ]

  capacity_reservation_specification = {
    capacity_reservation_preference = "open"
  }

  cpu_options = {
    core_count       = 1
    threads_per_core = 1
  }

  credit_specification = {
    cpu_credits = "standard"
  }

  # enclave_options = {
  #   enabled = true # Cannot enable hibernation and nitro enclaves on same instance nor on T3 instance type
  # }

  # hibernation_options = {
  #   configured = true # Root volume must be encrypted & not spot to enable hibernation
  # }

  instance_market_options = {
    market_type = "spot"
  }

  metadata_options = {
    http_endpoint = "enabled"
    # http_tokens                 = "required" # need to change?
    http_tokens                 = "optional" # At production grade you can change to "required", for our example if is optional we can get the content in metadata.html
    http_put_response_hop_limit = 32
    instance_metadata_tags      = "enabled"
  }

  # network_interfaces = [
  #   {
  #     delete_on_termination = true
  #     description           = "eth0"
  #     device_index          = 0
  #     security_groups       = [module.private_sg.security_group_id]
  #   },
  #   {
  #     delete_on_termination = true
  #     description           = "eth1"
  #     device_index          = 1
  #     security_groups       = [module.private_sg.security_group_id]
  #   }
  # ]

  # placement = {
  #   availability_zone = "${var.aws_region}b" # need to change? This must be reviewed!!
  # }

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { WhatAmI = "Instance" }
    },
    {
      resource_type = "volume"
      tags          = merge({ WhatAmI = "Volume" })
    },
    {
      resource_type = "spot-instances-request"
      tags          = merge({ WhatAmI = "SpotInstanceRequest" })
    }
  ]

  tags = local.common_tags

  # Autoscaling Schedule
  schedules = {
    morning = {
      scheduled_action_name = "increase-capacity-9am"
      min_size              = 2
      max_size              = 4
      desired_capacity      = 4
      start_time            = "2030-12-11T09:00:00Z"
      recurrence            = "00 09 * * *"
      # time_zone        = "Europe/Rome"
    }

    night = {
      scheduled_action_name = "decrease-capacity-9pm"
      min_size              = 2
      max_size              = 4
      desired_capacity      = 2
      start_time            = "2030-12-11T21:00:00Z"
      recurrence            = "00 21 * * *"
    }
  }

  # Target scaling policy schedule based on average CPU load
  scaling_policies = {
    avg-cpu-policy-greater-than-50 = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 1200
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = 50.0
      }
    },
    predictive-scaling = {
      policy_type = "PredictiveScaling"
      predictive_scaling_configuration = {
        mode                         = "ForecastAndScale"
        scheduling_buffer_time       = 10
        max_capacity_breach_behavior = "IncreaseMaxCapacity"
        max_capacity_buffer          = 10
        metric_specification = {
          target_value = 32
          predefined_scaling_metric_specification = {
            predefined_metric_type = "ASGAverageCPUUtilization"
            resource_label         = "testLabel"
          }
          predefined_load_metric_specification = {
            predefined_metric_type = "ASGTotalCPUUtilization"
            resource_label         = "testLabel"
          }
        }
      }
    },
    # https://github.com/terraform-aws-modules/terraform-aws-autoscaling/issues/192
    request-count-per-target = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 120
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ALBRequestCountPerTarget"
          resource_label         = "${module.alb.lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"
        }
        target_value = 10.0
      }
    }
  }
}
