# Version Management

## Overview
Versions are managed in `versions/manifest.json` using a structured JSON format.

## Structure
- `base.tools`: Versions for base image tools
- `agents`: Versions for different agent types
- `terraform`: List of supported Terraform versions

## Updating Versions
1. Update version in manifest.json
2. Create PR
3. Wait for Dependabot checks
4. Merge after approval

## Dependabot Integration
Automatic updates are configured for:
- Patch updates: Automatically created
- Minor updates: Automatically created
- Major updates: Manual review required
