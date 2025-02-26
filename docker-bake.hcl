#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

#
# make is calling the ./scripts/build_images.sh who calls docker buildx bake
#

group "default" {
  targets = ["rover_local"]
}

group "pr" {
  targets = ["rover_local", "rover_registry"]
}

group "release" {
  targets = ["rover_registry"]
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
  network = ["host"]
  allow = [
    "network.host",
    "security.insecure"
  ]
}

target "rover_base_${versionTerraform}" {
  inherits = ["common"]
  matrix = {
    platform = ["linux/amd64", "linux/arm64"]
  }
  platforms = ["${platform}"]
  args = {
    TARGETARCH = "${platform == "linux/amd64" ? "amd64" : "arm64"}"
    TARGETOS = "linux"
  }
}

target "rover_local" {
  inherits = ["rover_base_${versionTerraform}"]
  tags = ["rover:local"]
  output = ["type=docker"]
  platforms = ["linux/amd64"]
  no-cache = false
}

target "rover_registry" {
  inherits = ["rover_base_${versionTerraform}"]
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

variable "versionRover" {
  default = ""
}

variable "versionTerraform" {
  default = ""
}

variable "registry" {
  default = ""
}
