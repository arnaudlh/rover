# Version variables
variable "versionGithubRunner" {
  default = "2.314.1"
}

variable "versionAzdo" {
  default = "3.234.0"
}

variable "versionTfc" {
  default = "1.7.4"
}

variable "versionDockerCompose" {
  default = "2.24.1"
}

variable "versionGolang" {
  default = "1.21.6"
}

variable "versionAnsible" {
  default = "2.16.2"
}

variable "extensionsAzureCli" {
  default = "aks-preview"
}

variable "VERSION" {
  default = ""
}

variable "TARGETARCH" {
  default = "amd64"
}

variable "TARGETOS" {
  default = "linux"
}

variable "GITHUB_REPOSITORY" {
  default = ""
}

variable "GITHUB_SHA" {
  default = ""
}

variable "REGISTRY" {
  default = "ghcr.io"
}

variable "versionTerraform" {
  default = ""
}

# Base configuration
target "base" {
  context = "."
  args = {
    REGISTRY = "${REGISTRY}"
    GITHUB_REPOSITORY = "${GITHUB_REPOSITORY}"
    GITHUB_SHA = "${GITHUB_SHA}"
    TARGETARCH = "${TARGETARCH}"
    TARGETOS = "${TARGETOS}"
    USERNAME = "vscode"
    versionGithubRunner = "${versionGithubRunner}"
    versionAzdo = "${versionAzdo}"
    versionTfc = "${versionTfc}"
    versionDockerCompose = "${versionDockerCompose}"
    versionGolang = "${versionGolang}"
    versionAnsible = "${versionAnsible}"
    extensionsAzureCli = "${extensionsAzureCli}"
  }
  cache-from = ["type=gha,scope=pr-${TARGETARCH}"]
  cache-to = ["type=gha,mode=max,scope=pr-${TARGETARCH}"]
  network = "host"
  allow = "network.host,security.insecure"
}

# Build configuration for rover agents - local build
target "agent-1_9_8" {
  inherits = ["base"]
  dockerfile = "./agents/github/Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-github:${VERSION}-amd64"]
}

# Build configuration for rover agents - registry build
target "github" {
  inherits = ["base"]
  dockerfile = "./agents/github/Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-github:${VERSION}-${TARGETARCH}"]
}

target "tfc" {
  inherits = ["base"]
  dockerfile = "./agents/tfc/Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-tfc:${VERSION}-${TARGETARCH}"]
}

target "azdo" {
  inherits = ["base"]
  dockerfile = "./agents/azure_devops/Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-azdo:${VERSION}-${TARGETARCH}"]
}

target "gitlab" {
  inherits = ["base"]
  dockerfile = "./agents/gitlab/Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-gitlab:${VERSION}-${TARGETARCH}"]
}

# Default group
group "default" {
  targets = ["agent-1_9_8"]
}

# Registry build group
group "rover-agents" {
  targets = ["github", "tfc", "azdo", "gitlab"]
}
