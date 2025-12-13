module "s3-config" {
  source            = "./modules/s3"
  prefix            = var.project_name
  enable_versioning = var.s3_enable_versioning
  tags              = local.tags
  upload_files      = local.s3_upload_config
}

module "vpc" {
  source                 = "./modules/vpc"
  name                   = var.project_name
  availability_zones     = var.availability_zones
  one_nat_gateway_per_az = var.one_nat_gateway_per_az
  tags                   = local.tags
}

module "alb" {
  source = "./modules/alb"

  project_name              = var.project_name
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.public_subnet_ids
  target_instance_ids       = []
  create_target_attachments = false
  target_port               = var.vscode_server_port
  tags                      = local.tags
}

module "vscode_server" {
  source = "./modules/vscode-server"

  name                       = var.project_name
  vpc_id                     = module.vpc.vpc_id
  subnet_id                  = module.vpc.private_subnet_ids[0]
  instance_type              = var.instance_type
  vscode_server_port         = var.vscode_server_port
  allowed_security_group_ids = [module.alb.security_group_id]
  s3_bucket_name             = module.s3-config.bucket_id
  tags                       = local.tags

  # depends_on = [
  #   module.alb,
  #   module.s3-config
  # ]
}

# Target group attachment (created after vscode_server instance exists)
resource "aws_lb_target_group_attachment" "vscode" {
  target_group_arn = module.alb.target_group_arn
  target_id        = module.vscode_server.instance_id
  port             = var.vscode_server_port
}
