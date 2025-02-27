# Version variables
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

variable "versionRover" {
  default = "localhost:5000/rover:local"
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
    versionRover = "${versionRover}"
  }
  cache-from = ["type=gha,scope=pr-${TARGETARCH}"]
  cache-to = ["type=gha,mode=max,scope=pr-${TARGETARCH}"]
  network = "host"
  allow = "network.host,security.insecure"
}

# Build targets for each agent type
target "github" {
  inherits = ["base"]
  dockerfile = "./agents/github/Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-github:${VERSION}-amd64"]
}

target "tfc" {
  inherits = ["base"]
  dockerfile = "./agents/tfc/Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-tfc:${VERSION}-amd64"]
}

target "azdo" {
  inherits = ["base"]
  dockerfile = "./agents/azure_devops/Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-azdo:${VERSION}-amd64"]
}

target "gitlab" {
  inherits = ["base"]
  dockerfile = "./agents/gitlab/Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-gitlab:${VERSION}-amd64"]
}

# Default group
group "default" {
  targets = ["github", "tfc", "azdo", "gitlab"]
}
