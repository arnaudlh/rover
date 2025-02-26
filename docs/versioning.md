# Versioning and Tagging Strategy

## Overview
This document describes the versioning and tagging strategies used in the rover project for both release and development builds.

## Image Tags

### Release Builds
Release builds use the following tag format:
```
${versionTerraform}-${tag_date_release}
```
Where:
- `versionTerraform`: The version of Terraform being packaged
- `tag_date_release`: Release date in YYYYMMDD format

### Development/PR Builds
PR builds use the following tag format:
```
${versionTerraform}-${platform}
```
Where:
- `versionTerraform`: The version of Terraform being packaged
- `platform`: The target platform (e.g., linux/amd64, linux/arm64)

### Agent Images
Agent images (GitHub, Azure DevOps, TFC) follow similar patterns with additional suffixes:
- Release: `rover-agent-${agent_type}:${versionTerraform}-${tag_date_release}`
- PR: `rover-agent-${agent_type}:${versionTerraform}-${platform}`

## Version Management

### Tool Versions
Tool versions are managed in `versions/manifest.json` and parsed using `scripts/parse_versions.sh`. This includes:
- Terraform versions
- Agent versions (GitHub Runner, Azure DevOps, TFC)
- Supporting tools (Docker Compose, kubectl, etc.)

### Version Selection
- Latest stable Terraform version is automatically selected from manifest
- Agent versions are explicitly specified in manifest
- Tool versions can be overridden via environment variables

## Build Process
1. Base image is built first with platform-specific tags
2. Agent images are built using the base image as their foundation
3. Each build validates tool versions before proceeding
4. Version information is preserved in the image metadata

## Cache Management
- Build cache uses unique keys based on platform and version
- Cache entries are preserved for improved build performance
- Non-retryable cache conflicts are handled gracefully

## Examples

### Release Tag
```
ghcr.io/org/rover:1.5.0-20240224
ghcr.io/org/rover-agent-github:1.5.0-20240224
```

### PR/Development Tag
```
ghcr.io/org/rover:1.5.0-linux-amd64
ghcr.io/org/rover-agent-azdo:1.5.0-linux-arm64
```
