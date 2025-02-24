variable "versionGithubRunner" {
  default = "2.314.1"
}

variable "versionAzdo" {
  default = "3.234.0"
}

variable "versionTfc" {
  default = "1.7.4"
}

group "agents" {
  targets = ["agent-matrix"]
}

target "agent-common" {
  context = "."
  args = {
    TARGETARCH = "${TARGETARCH}"
    TARGETOS = "${TARGETOS}"
    USERNAME = "vscode"
    versionGithubRunner = "${versionGithubRunner}"
    versionAzdo = "${versionAzdo}"
    versionTfc = "${versionTfc}"
  }
  cache-from = ["type=gha,scope=${GITHUB_REF_NAME}-agent-${TARGETARCH}"]
  cache-to = ["type=gha,mode=max,scope=${GITHUB_REF_NAME}-agent-${TARGETARCH}"]
  network = ["host"]
  allow = [
    "network.host",
    "security.insecure"
  ]
}

target "agent-matrix" {
  inherits = ["agent-common"]
  matrix = {
    agent = ["github", "tfc", "azdo", "gitlab"]
    platform = ["linux/amd64", "linux/arm64"]
  }
  dockerfile = "./agents/${agent}/Dockerfile"
  platforms = ["${platform}"]
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/rover-agent-${agent}:${TAG}"]
}
