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

# Build matrix target
target "matrix-base" {
  inherits = ["base"]
  matrix = {
    agent = ["github", "tfc", "azdo", "gitlab"]
    platform = ["linux/amd64"]
  }
  dockerfile = "./agents/${agent}/Dockerfile"
  platforms = ["${platform}"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-${agent}:${VERSION}-${platform == "linux/amd64" ? "amd64" : "arm64"}"]
}

# Version-specific target
target "agent" {
  inherits = ["matrix-base"]
}

# Default group
group "default" {
  targets = ["agent"]
}
