variable "name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the VS Code Server will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where the VS Code Server EC2 instance will be deployed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for VS Code Server"
  type        = string
  default     = "t3.small"
}

variable "vscode_server_port" {
  description = "Port on which VS Code Server will listen"
  type        = number
  default     = 8000
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to access the VS Code Server port. If provided, traffic from these security groups will be allowed."
  type        = list(string)
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the VS Code Server port. If provided, traffic from these CIDR blocks will be allowed."
  type        = list(string)
  default     = null
}

variable "additional_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to the EC2 instance role"
  type        = list(string)
  default     = []
}

variable "additional_policy_statements" {
  description = "List of additional IAM policy statements to add as an inline policy. Each statement should be a map with Effect, Action, and Resource keys."
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default = []
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to mount. If provided, the bucket will be mounted to /mnt/s3_config"
  type        = string
  default     = null
}

variable "vscode_theme" {
  description = "VS Code Server theme (e.g., 'Default Dark Modern', 'Default Light Modern', 'Default High Contrast')"
  type        = string
  default     = "Default Dark Modern"
}
