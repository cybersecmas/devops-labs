# Create Elastic IP for Bastion Host
# Resource - depends_on Meta-Argument
resource "aws_eip" "bastion_eip" {
  depends_on = [module.ec2_public, module.vpc]
  # instance   = module.ec2_public.id[0]
  instance = module.ec2_public.id
  vpc      = true
  tags     = local.common_tags

  ## Local Exec Provisioner:  local-exec provisioner (Destroy-Time Provisioner - Triggered during deletion of Resource)
  provisioner "local-exec" {
    command     = "echo Destroy time prov `date` >> destroy-time-prov.txt"
    working_dir = "local-exec-output/"
    when        = destroy
    # on_failure = continue
  }
}
