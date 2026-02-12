# Example Terraform configuration for testing
# This creates a simple local file resource

terraform {
  required_version = ">= 1.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

variable "content" {
  description = "Content for the file"
  type        = string
  default     = "Hello from Terraform!"
}

variable "filename" {
  description = "Name of the file to create"
  type        = string
  default     = "output.txt"
}

resource "local_file" "example" {
  content  = var.content
  filename = "${path.module}/${var.filename}"
}

output "file_path" {
  description = "Path to the created file"
  value       = local_file.example.filename
}
