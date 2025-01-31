# Environment Variables and Build Arguments

This document describes the environment variables and build arguments used in the rover project.

## Docker Build Arguments

### Base Image Arguments
- `USERNAME` (default: vscode) - The username for the container user
- `USER_UID` (default: 1000) - User ID for the container user
- `USER_GID` (default: USER_UID) - Group ID for the container user
- `SSH_PASSWD` - SSH password for the container user
- `TARGETARCH` - Target architecture for the build (amd64/arm64)
- `TARGETOS` - Target operating system for the build
- `versionRover` - Version tag for the rover image

## Runtime Environment Variables

### Core Variables
- `SSH_PASSWD` - SSH password configured during build
- `USERNAME` - Container user (defaults to build arg value)
- `versionRover` - Rover version tag

### Agent-specific Variables (when using rover-agent)
- `AGENT_KEYVAULT_NAME` - Azure KeyVault name for agent secrets
- `AGENT_KEYVAULT_SECRET` - Secret name in Azure KeyVault
- `AGENT_NAME` - Name of the agent instance
- `AGENT_TOKEN` - Authentication token for the agent
- `AGENT_URL` - URL for agent communication
- `LABELS` - Agent labels for job targeting
- `MSI_ID` - Managed Service Identity ID
- `REGISTER_PAUSED` - Whether to start agent in paused state (default: false)

## Usage Examples

### Building the Image
```bash
# Build with custom user
docker build --build-arg USERNAME=myuser .

# Build for specific architecture
docker build --build-arg TARGETARCH=arm64 .
```

### Running the Container
```bash
# Run with custom SSH password
docker run -e SSH_PASSWD=mypassword aztfmod/rover:latest

# Run with Azure KeyVault integration
docker run \
  -e AGENT_KEYVAULT_NAME=myvault \
  -e AGENT_KEYVAULT_SECRET=mysecret \
  aztfmod/rover-agent:latest
```

## Environment Impact on Features

### Security Scanning
The security scanning process uses the following variables:
- `TARGETARCH` and `TARGETOS` for platform-specific scanning
- Container registry authentication via GitHub Actions environment

### CI/CD Pipeline
The CI/CD process relies on:
- `versionRover` for image tagging
- GitHub-provided environment variables for authentication
- Agent-specific variables when running in agent mode

### Local Development
For local development:
- `USERNAME` and `USER_UID` affect container user permissions
- `SSH_PASSWD` enables SSH access if needed
- Dev container configuration inherits from base environment settings
