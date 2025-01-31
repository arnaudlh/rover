# Continuous Integration

The rover project implements a comprehensive CI/CD pipeline using GitHub Actions, combining code quality tools, multi-platform builds, and security scanning.

## Build Process

### Multi-Platform Build Matrix

The build workflow supports multiple architectures through a build matrix configuration:
```yaml
strategy:
  matrix:
    platform: [linux/amd64, linux/arm64]  # Builds for both Intel/AMD and ARM processors
```

This enables:
- Native performance on Apple Silicon (M1/M2) and AWS Graviton
- Compatibility with traditional x86_64 systems
- Automatic architecture selection when pulling images

Features:
- Docker layer caching for faster builds
- Multi-stage Docker builds for optimized image size
- Parallel builds across architectures
- Automated tagging and versioning

### Security Scanning

Security scanning runs as a separate workflow after successful builds:
1. Container scanning with Anchore:
   - Severity cutoff: critical
   - Non-blocking (fail-build: false)
   - Results uploaded as SARIF reports
2. View scan results:
   - GitHub Security tab
   - Code scanning alerts section
   - Filter by Anchore scanner

## Local CI Tools

Rover ci invokes predefined tools to ensure code quality. These tools are defined in [scripts/ci_tasks](../scripts/ci_tasks).

### Pre-requisites

* Landing zones and configs cloned to base directory (eg. /tf/caf)
* A symphony.yaml file. See [samples.symphony.yaml](symphony/sample.symphony.yaml)

### Usage

Run all CI tools:
```shell
rover ci -sc /tf/config/symphony.yml -b /tf/caf -env demo -d
```

Run specific tool (e.g., tflint):
```shell
rover ci -ct tflint -sc /tf/config/symphony.yml -b /tf/caf -env demo -d
```

### Available Tools

* tflint - Terraform linter
* tfsec - Security scanner for Terraform code
* checkov - Policy-as-code scanner
* terrascan - Security vulnerability scanner

### Pre-commit Integration

CI tools are also available as pre-commit hooks. See [PRE-COMMIT.md](PRE-COMMIT.md) for setup.

## GitHub Actions Workflows

### Build Workflow
- Triggers:
  - Push to roverlight branch
  - Release creation
  - Manual dispatch
- Builds multi-arch images
- Publishes to GitHub Container Registry

### Security Scan Workflow
- Runs after successful builds
- Scans published container images
- Uploads results to GitHub Security
- Non-blocking for faster feedback

## Viewing Results

1. Build Status:
   - GitHub Actions tab
   - Filter by workflow name

2. Security Scans:
   - Security tab > Code scanning
   - Security tab > Container scanning

3. Container Registry:
   - Packages tab
   - Filter by "roverlight"
