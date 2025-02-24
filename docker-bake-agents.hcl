group "agents" {
  targets = ["agent-matrix"]
}

target "agent-common" {
  context = "."
  args = {
    TARGETARCH = "${TARGETARCH}"
    TARGETOS = "${TARGETOS}"
    USERNAME = "vscode"
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
