# Go Development Dockerfile for Bolt
# Base image: Go 1.22 Alpine (lightweight)
FROM golang:1.22-alpine

# Install git and build tools (required for some Go packages)
RUN apk add --no-cache git gcc musl-dev

# Set working directory
WORKDIR /project

# Default command: shell for interactive use
CMD ["/bin/sh"]
