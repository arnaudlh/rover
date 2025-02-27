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

# Base configuration
target "rover-base" {
  context = "."
  args = {
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
  cache-from = ["type=gha,scope=${GITHUB_REF_NAME}-${TARGETARCH}"]
  cache-to = ["type=gha,mode=max,scope=${GITHUB_REF_NAME}-${TARGETARCH}"]
  network = ["host"]
  allow = [
    "network.host",
    "security.insecure"
  ]
}

# Build matrix
target "agent-build" {
  inherits = ["rover-base"]
  matrix = {
    agent = ["github", "tfc", "azdo", "gitlab"]
    platform = ["linux/amd64", "linux/arm64"]
  }
  dockerfile = "./agents/${agent}/Dockerfile"
  platforms = ["${platform}"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-${agent}:${VERSION}-${platform == "linux/amd64" ? "amd64" : "arm64"}"]
}

# Default group
group "default" {
  targets = ["agent-build"]
}
