# AWS IAM Service Linked Role for Autoscaling Group
resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = local.name

  # Sometimes good sleep is required to have some IAM resources created before they can be used
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# Output AWS IAM Service Linked Role
output "service_linked_role_arn" {
  value = aws_iam_service_linked_role.autoscaling.arn
}

# -----------------------------------------------
# More resources newly added here
# -----------------------------------------------

# resource "aws_iam_instance_profile" "ssm" {
#   name = "complete-${local.name}"
#   role = aws_iam_role.ssm.name
#   tags = local.common_tags # need to change?
# }

# resource "aws_iam_role" "ssm" {
#   name = "complete-${local.name}"
#   tags = local.common_tags # need to change?

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = "sts:AssumeRole",
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         },
#         Effect = "Allow",
#         Sid    = ""
#       }
#     ]
#   })
# }
