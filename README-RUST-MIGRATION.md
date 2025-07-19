# Rover Shell to Rust Migration

This document describes the migration of the Rover project from Shell scripts to Rust.

## Overview

The Rover project has been converted from Shell scripts to Rust while maintaining all core functionality:

- **Terraform operations**: plan, apply, destroy, validate, refresh, graph, output, show
- **Azure authentication**: Service principal, device code flow, Key Vault integration
- **State management**: AzureRM and Terraform Cloud backends
- **Multi-architecture support**: linux/amd64, linux/arm64
- **CI/CD agent images**: GitHub Actions, Azure DevOps, GitLab, Terraform Cloud

## Key Changes

### Removed Components (Symphony)
The following Symphony-related components have been completely removed as requested:
- `scripts/ci.sh`
- `scripts/cd.sh` 
- `scripts/symphony_yaml.sh`
- All Symphony infrastructure references

### New Rust Structure
```
src/
├── main.rs              # Entry point
├── lib.rs               # Library root
├── config/              # Configuration management
├── commands/            # Command implementations
├── auth/                # Azure authentication
├── terraform/           # Terraform operations
│   ├── state.rs         # State management
│   ├── cloud.rs         # Terraform Cloud integration
│   └── commands.rs      # Terraform command execution
├── docker/              # Docker operations
├── logging.rs           # Logging setup
└── utils.rs             # Utility functions
```

### Backward Compatibility
- `scripts/rover.sh` now acts as a wrapper that calls the Rust binary
- `scripts/rover-wrapper.sh` provides additional compatibility for complex argument mapping
- Environment variables and CLI arguments remain the same

### Docker Integration
- Multi-stage Docker build with Rust compilation
- Rust binary replaces shell scripts in container images
- All external tool dependencies preserved (Azure CLI, Terraform, kubectl, etc.)

## Building

```bash
# Build Rust binary
cargo build --release

# Run tests
cargo test

# Lint code
cargo clippy -- -D warnings

# Format code
cargo fmt

# Build Docker images
make github
```

## Usage

The Rust rover binary maintains the same CLI interface:

```bash
# Terraform operations
rover init /path/to/landingzone --plan
rover init /path/to/landingzone --apply
rover init /path/to/landingzone --destroy

# Azure authentication
rover login --tenant <tenant-id> --subscription <subscription-id>
rover logout

# Workspace management
rover workspace list
rover workspace create <name>
rover workspace delete <name>

# Launchpad operations
rover launchpad /path/to/launchpad --plan
rover launchpad /path/to/launchpad --apply

# Bootstrap
rover bootstrap --aad-app-name <app-name>

# Utility operations
rover purge
rover landingzone list
```

## Environment Variables

All existing environment variables are supported:

- `TF_VAR_level` - Terraform level
- `TF_VAR_workspace` - Terraform workspace
- `TF_DATA_DIR` - Terraform data directory
- `ARM_SUBSCRIPTION_ID` - Azure subscription ID
- `ARM_TENANT_ID` - Azure tenant ID
- `ARM_CLIENT_ID` - Azure client ID
- `ARM_CLIENT_SECRET` - Azure client secret
- `TF_VAR_tf_cloud_hostname` - Terraform Cloud hostname
- `TF_VAR_tf_cloud_organization` - Terraform Cloud organization
- `LOG_SEVERITY` - Logging level (VERBOSE, DEBUG, INFO, WARN, ERROR, FATAL)

## Microsoft Azure Best Practices

The Rust implementation follows Microsoft Azure best practices:

- **Error Handling**: Proper `Result<T, E>` error handling with context
- **Logging**: Structured logging with tracing crate
- **Security**: No secrets in logs, proper credential management
- **Performance**: Async operations with tokio runtime
- **Reliability**: Exponential backoff for retries
- **Observability**: Detailed tracing and error context

## CI/CD Pipeline

The updated CI/CD pipeline includes:

- **Unit Tests**: `cargo test` on every push
- **Linting**: `cargo clippy` for code quality
- **Security Scanning**: Microsoft Security DevOps Action
- **Multi-Architecture Builds**: Parallel builds for linux/amd64 and linux/arm64
- **Agent Matrix**: Parallel builds for github, tfc, azdo, gitlab agents

## Migration Notes

1. **Functionality Parity**: All original rover functionality has been preserved
2. **Performance**: Rust implementation provides better performance and memory safety
3. **Maintainability**: Structured code with proper error handling and testing
4. **Compatibility**: Existing scripts and workflows continue to work
5. **Future-Proof**: Modern Rust ecosystem with excellent Azure SDK support

## Testing

The conversion has been tested to ensure:
- All CLI commands work as expected
- Azure authentication flows function correctly
- Terraform operations execute properly
- Docker builds complete successfully
- Multi-architecture support is maintained
