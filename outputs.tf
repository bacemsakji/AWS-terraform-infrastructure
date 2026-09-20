# outputs.tf
# After `terraform apply`, Terraform prints these values in your terminal.
# Useful so you don't have to go digging in the AWS console to find your
# instance's IP address.

output "instance_public_ip" {
  description = "SSH into this, or open it in a browser for Jenkins (:8080)"
  value       = aws_instance.server.public_ip
}

output "jenkins_url" {
  value = "http://${aws_instance.server.public_ip}:8080"
}

output "app_url" {
  description = "Once deployed, your app is reachable here"
  value       = "http://${aws_instance.server.public_ip}:30080"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}
