# =============================================================================
# IAM ROLE FOR EC2 INSTANCE (SSM ACCESS)
# =============================================================================

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get current AWS region
data "aws_region" "current" {}

# IAM role for EC2 instance
resource "aws_iam_role" "ec2_vscode" {
  name = "${var.name}-ec2-vscode-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name}-ec2-vscode-role"
  })
}

# Attach SSM managed policy
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_vscode.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach policy for SSM Parameter Store access
resource "aws_iam_role_policy" "ec2_ssm_parameter" {
  name = "${var.name}-ec2-ssm-parameter-policy"
  role = aws_iam_role.ec2_vscode.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMParameterStoreAccess"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameterHistory"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.name}/vscode-server/*"
      }
    ]
  })
}

# Attach policy for S3 read access
resource "aws_iam_role_policy" "ec2_s3_read" {
  name = "${var.name}-ec2-s3-read-policy"
  role = aws_iam_role.ec2_vscode.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ListAllBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3GetBucketMetadata"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = "arn:aws:s3:::${var.s3_bucket_name}"
      },
      {
        Sid    = "S3GetObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/*"
      }
    ]
  })
}

# Attach additional managed policies
resource "aws_iam_role_policy_attachment" "additional" {
  count      = length(var.additional_policy_arns)
  role       = aws_iam_role.ec2_vscode.name
  policy_arn = var.additional_policy_arns[count.index]
}

# Attach additional inline policy with custom statements
resource "aws_iam_role_policy" "additional" {
  count = length(var.additional_policy_statements) > 0 ? 1 : 0
  name  = "${var.name}-ec2-additional-policy"
  role  = aws_iam_role.ec2_vscode.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = var.additional_policy_statements
  })
}

# IAM instance profile
resource "aws_iam_instance_profile" "ec2_vscode" {
  name = "${var.name}-ec2-vscode-profile"
  role = aws_iam_role.ec2_vscode.name

  tags = merge(var.tags, {
    Name = "${var.name}-ec2-vscode-profile"
  })
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================

# Security group for EC2 instance
resource "aws_security_group" "ec2_vscode" {
  name        = "${var.name}-ec2-vscode-sg"
  description = "Security group for VS Code Server EC2 instance"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_security_group_ids != null ? [1] : []
    content {
      description     = "VS Code Server from allowed security groups"
      from_port       = var.vscode_server_port
      to_port         = var.vscode_server_port
      protocol        = "tcp"
      security_groups = var.allowed_security_group_ids
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks != null ? [1] : []
    content {
      description = "VS Code Server from allowed CIDR blocks"
      from_port   = var.vscode_server_port
      to_port     = var.vscode_server_port
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-ec2-vscode-sg"
  })
}

# =============================================================================
# AMAZON LINUX 2023 AMI DATA SOURCE
# =============================================================================

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# EC2 INSTANCE FOR VS CODE SERVER
# =============================================================================

# SSM Parameter for VS Code Server token (will be populated by user data script)
resource "aws_ssm_parameter" "vscode_token" {
  name        = "/${var.name}/vscode-server/token"
  description = "VS Code Server authentication token"
  type        = "SecureString"
  value       = "placeholder" # Will be overwritten by user data script

  tags = merge(var.tags, {
    Name = "${var.name}-vscode-token"
  })

  lifecycle {
    ignore_changes = [value]
  }
}

# EC2 instance
resource "aws_instance" "vscode_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  iam_instance_profile   = aws_iam_instance_profile.ec2_vscode.name
  vpc_security_group_ids = [aws_security_group.ec2_vscode.id]

  root_block_device {
    volume_size = 30
  }

  user_data_base64 = base64encode(templatefile("${path.module}/user_data.sh", {
    vscode_port    = var.vscode_server_port
    token_param    = aws_ssm_parameter.vscode_token.name
    region         = data.aws_region.current.region
    s3_bucket_name = var.s3_bucket_name != null ? var.s3_bucket_name : ""
    vscode_theme   = var.vscode_theme
  }))

  user_data_replace_on_change = true

  tags = merge(var.tags, {
    Name = "${var.name}-vscode-server"
  })
}
