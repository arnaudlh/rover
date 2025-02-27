# Version variables
variable "versionTerraform" {
  default = ""
}

variable "registry" {
  default = ""
}

variable "versionRover" {
  default = ""
}

group "default" {
  targets = ["local-tf"]
}

group "pr" {
  targets = ["local-tf", "registry-tf"]
}

group "release" {
  targets = ["registry-tf"]
}

# Common target configuration
target "common" {
  dockerfile = "./Dockerfile"
  context = "."
  args = {
    TARGETARCH = "${TARGETARCH}"
    TARGETOS = "${TARGETOS}"
    USER_UID = "${USER_UID}"
    USER_GID = "${USER_GID}"
    USERNAME = "${USERNAME}"
  }
  cache-from = [
    "type=gha,scope=${GITHUB_REF_NAME}-${TARGETARCH}",
    "type=gha,scope=main-${TARGETARCH}"
  ]
  cache-to = ["type=gha,mode=max,scope=${GITHUB_REF_NAME}-${TARGETARCH}-${GITHUB_SHA}"]
  network = "host"
  allow = "network.host,security.insecure"
}

target "local-tf" {
  inherits = ["common"]
  platforms = ["linux/amd64"]
  tags = ["rover:local"]
  output = ["type=docker"]
  no-cache = false
}

target "registry-tf" {
  inherits = ["common"]
  platforms = ["linux/amd64", "linux/arm64"]
  tags = ["${registry}rover:${versionRover}"]
  output = ["type=registry"]
}

# Build configuration variables
variable "TARGETARCH" {
  default = "amd64"
}

variable "TARGETOS" {
  default = "linux"
}

variable "USER_UID" {
  default = "1000"
}

variable "USER_GID" {
  default = "1000"
}

variable "USERNAME" {
  default = "vscode"
}

variable "tag" {
  default = "latest"
}
