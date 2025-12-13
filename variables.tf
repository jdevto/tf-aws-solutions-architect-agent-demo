variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "example"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}

variable "one_nat_gateway_per_az" {
  description = "Should be true if you want one NAT Gateway per availability zone. Otherwise, one NAT Gateway will be used for all AZs."
  type        = bool
  default     = false
}

variable "instance_type" {
  description = <<-EOT
    EC2 instance type for VS Code Server and LLM inference.

    For Llama 3.1 8B CPU inference (LM Studio):
    - Minimum: t3a.xlarge (4 vCPUs, 16GB RAM) - works but slow
    - Recommended: t3a.2xlarge (8 vCPUs, 32GB RAM) - good balance of cost/performance
    - Better: c5.2xlarge (8 vCPUs, 16GB RAM) - compute-optimized, faster inference
    - Best: c5.4xlarge (16 vCPUs, 32GB RAM) - fastest CPU inference

    Note: For production LLM inference, consider GPU instances (g5.xlarge+) or
    AWS Inferentia (inf2.xlarge+) for 10-100x better performance.
  EOT
  type        = string
  default     = "t3a.2xlarge" # Recommended: 8 vCPUs for decent LLM inference performance
}

variable "vscode_server_port" {
  description = "Port on which VS Code Server will listen"
  type        = number
  default     = 8000
}

variable "s3_enable_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = false
}

variable "upload_agent_files" {
  description = "Upload agent files from scripts/agents/ directory to S3"
  type        = bool
  default     = true
}
