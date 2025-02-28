# Version Management

## Overview
This directory contains the version management system for the rover project.

## Structure
- `manifest.json`: Single source of truth for all component versions
  - base.tools: Versions for base image tools
  - agents: Versions for different agent types
  - terraform: List of supported Terraform versions

## Usage
Use the version parser script to access versions:
```bash
./scripts/parse_versions.sh tool vault      # Get tool version
./scripts/parse_versions.sh agent azdo      # Get agent version
./scripts/parse_versions.sh terraform       # List Terraform versions
```

## Updating Versions
1. Update version in manifest.json
2. Create PR
3. Wait for CI checks
4. Merge after approval
