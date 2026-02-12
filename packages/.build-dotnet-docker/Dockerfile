# .NET Development Dockerfile for Bolt
# Base image: .NET SDK 10.0 (latest stable)
FROM mcr.microsoft.com/dotnet/sdk:10.0

# Install git (required for some NuGet packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /project

# Default command: shell for interactive use
CMD ["/bin/bash"]
