output "instance_id" {
  description = "ID of the VS Code Server EC2 instance"
  value       = aws_instance.vscode_server.id
}

output "instance_private_ip" {
  description = "Private IP address of the VS Code Server EC2 instance"
  value       = aws_instance.vscode_server.private_ip
}

output "security_group_id" {
  description = "ID of the security group for the VS Code Server EC2 instance"
  value       = aws_security_group.ec2_vscode.id
}

output "ssm_parameter_name" {
  description = "Name of the SSM parameter storing the VS Code Server token"
  value       = aws_ssm_parameter.vscode_token.name
}
