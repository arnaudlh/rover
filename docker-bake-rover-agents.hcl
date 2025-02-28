# Version variables
variable "VERSION" {
  default = "latest"
}

variable "TARGETARCH" {
  default = "amd64"
}

variable "TARGETOS" {
  default = "linux"
}

variable "GITHUB_REPOSITORY" {
  default = "arnaudlh/rover"
}

variable "GITHUB_SHA" {
  default = "latest"
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

# Individual agent targets
target "github-agent" {
  inherits = ["base"]
  dockerfile = "./agents/github/Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["${REGISTRY}/${GITHUB_REPOSITORY}/rover-agent-github:${VERSION}-amd64"]
}

target "tfc-agent" {
  inherits = ["base"]
  dockerfile = "./agents/tfc/Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["${REGISTRY}/${GITHUB_REPOSITORY}/rover-agent-tfc:${VERSION}-amd64"]
}

target "azdo-agent" {
  inherits = ["base"]
  dockerfile = "./agents/azure_devops/Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["${REGISTRY}/${GITHUB_REPOSITORY}/rover-agent-azdo:${VERSION}-amd64"]
}

target "gitlab-agent" {
  inherits = ["base"]
  dockerfile = "./agents/gitlab/Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["${REGISTRY}/${GITHUB_REPOSITORY}/rover-agent-gitlab:${VERSION}-amd64"]
}

# Default group
group "default" {
  targets = ["github-agent", "tfc-agent", "azdo-agent", "gitlab-agent"]
}
