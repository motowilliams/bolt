# Terraform Development Dockerfile for Bolt
# Base image: HashiCorp Terraform latest
FROM hashicorp/terraform:latest

# Install additional tools (git, bash)
RUN apk add --no-cache git bash

# Set working directory
WORKDIR /tf

# Default command: shell for interactive use
CMD ["/bin/bash"]
