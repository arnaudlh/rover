#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

#
# make is calling the ./scripts/build_images.sh who calls docker buildx bake
#

group "default" {
  targets = ["rover_local", "roverlight_local"]
}

target "rover_local" {
  dockerfile = "./Dockerfile"
  tags = ["rover_local:${tag}"]
  args = {
    extensionsAzureCli   = extensionsAzureCli
    versionDockerCompose = versionDockerCompose
    versionGolang        = versionGolang
    versionKubectl       = versionKubectl
    versionKubelogin     = versionKubelogin
    versionPacker        = versionPacker
    versionPowershell    = versionPowershell
    versionRover         = versionRover
    versionTerraform     = versionTerraform
    versionTerraformDocs = versionTerraformDocs
    versionVault         = versionVault
    versionAnsible       = versionAnsible
    versionTerrascan     = versionTerrascan
    versionTfupdate      = versionTfupdate
  }
  platforms = ["linux/arm64", "linux/amd64" ]
  # cache-to = ["type=local,dest=/tmp/.buildx-cache,mode=max"]
  # cache-from = ["type=local,src=/tmp/.buildx-cache"]
}

target "roverlight_local" {
  dockerfile = "./Dockerfile.roverlight"
  tags = ["roverlight_local:${tag}"]
  platforms = ["linux/arm64", "linux/amd64"]
  # cache-to = ["type=local,dest=/tmp/.buildx-cache,mode=max"]
  # cache-from = ["type=local,src=/tmp/.buildx-cache"]
}

target "rover_registry" {
  inherits = ["rover_local"]
  tags = ["${versionRover}"]
  args = {
    image     = versionRover
  }
}

target "roverlight_registry" {
  inherits = ["roverlight_local"]
  tags = ["${versionRover}"]
  args = {
    image     = versionRover
  }
}

variable "registry" {
    default = ""
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