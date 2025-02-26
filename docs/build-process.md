# Build Process Documentation

## Overview
This document describes the build process for the rover project, including base images and agents.

## Build Matrix
The build process supports multiple platforms and agent types:
- Platforms: linux/amd64, linux/arm64
- Agents: GitHub Runner, Azure DevOps, TFC, GitLab

## Build Stages

### 1. Base Image
- Ubuntu 24.04 (Noble Numbat) base
- Multi-stage build for optimized image size
- Platform-specific package installation
- Comprehensive retry mechanisms for reliability

### 2. Agent Images
Each agent type is built with:
- Platform-specific binaries
- Proper user/group permissions
- Environment configuration
- Health checks and verification

## Build Configuration

### Base Image
```hcl
target "base-tf" {
  inherits = ["common"]
  matrix = {
    platform = ["linux/amd64", "linux/arm64"]
  }
  args = {
    TARGETARCH = "${platform == "linux/amd64" ? "amd64" : "arm64"}"
    TARGETOS = "linux"
    versionTerraform = "${versionTerraform}"
  }
  tags = ["rover:${versionTerraform}-${platform}"]
}
```

### Agent Images
```hcl
target "agent-tf" {
  inherits = ["agent-common"]
  matrix = {
    agent = ["github", "tfc", "azdo", "gitlab"]
    platform = ["linux/amd64", "linux/arm64"]
  }
  dockerfile = "./agents/${agent}/Dockerfile"
  platforms = ["${platform}"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-${agent}:${VERSION}-${platform}"]
}
```

## Error Handling
- Retry mechanisms for package installation
- Proper exit code handling
- Detailed logging for troubleshooting
- Cache conflict management

## Security Scanning
- MSDO integration for security analysis
- Terrascan configuration
- SARIF output generation
- Comprehensive vulnerability reporting
