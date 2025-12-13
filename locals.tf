locals {
  tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  s3_upload_config = var.upload_agent_files ? {
    source_dir   = "${path.root}/scripts/agents"
    file_pattern = "**/*"
    s3_prefix    = "agents"
    content_types = {
      ".py"   = "text/x-python"
      ".sh"   = "text/x-shellscript"
      ".txt"  = "text/plain"
      ".json" = "application/json"
      ".yaml" = "text/yaml"
      ".yml"  = "text/yaml"
      ".md"   = "text/markdown"
    }
  } : null
}
