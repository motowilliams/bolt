# Python Development Dockerfile for Bolt
# Base image: Python 3.12 Slim (smaller than full image)
FROM python:3.12-slim

# Install essential build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /project

# Default command: shell for interactive use
CMD ["/bin/bash"]
