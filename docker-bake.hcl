#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

#
# make is calling the ./scripts/build_images.sh who calls docker buildx bake
#

group "default" {
  targets = ["rover_local", "rover_agents"]
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
    versionVault = "1.15.0"
    versionGolang = "1.21.6"
    versionKubectl = "1.28.4"
    versionKubelogin = "0.1.0"
    versionDockerCompose = "2.24.1"
    versionTerraformDocs = "0.17.0"
    versionPacker = "1.10.0"
    versionPowershell = "7.4.1"
    versionAnsible = "2.16.2"
    extensionsAzureCli = "aks-preview"
    versionTerrascan = "1.18.3"
    versionTfupdate = "0.7.2"
  }
  cache-from = ["type=local,src=/tmp/.buildx-cache"]
  cache-to = ["type=local,dest=/tmp/.buildx-cache-new,mode=max"]
}

target "rover_local" {
  inherits = ["common"]
  tags = ["rover:local"]
  platforms = ["${TARGETOS}/${TARGETARCH}"]
  output = ["type=docker"]
  target = "base"
  no-cache = false
}

target "rover_registry" {
  inherits = ["common"]
  tags = ["${registry}rover:${versionRover}"]
  platforms = ["linux/amd64", "linux/arm64"]
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
