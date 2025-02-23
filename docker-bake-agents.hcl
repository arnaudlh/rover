#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

#
# make is calling the ./scripts/build_images.sh who calls docker buildx bake
#

variable "registry" {
  default = ""
}

variable "tag" {
  default = ""
}

variable "tag_strategy" {
  default = ""
}

variable "versionRover" {
  default = ""
}

group "rover_agents" {
  targets = ["github", "tfc", "azdo", "gitlab"]
}

target "common_agent" {
  context = "."
  args = {
    USERNAME = "vscode"
    versionRover = ""
  }
  platforms = ["linux/amd64"]
  output = ["type=docker"]
  cache-from = ["type=local,src=/tmp/.buildx-cache"]
  cache-to = ["type=local,dest=/tmp/.buildx-cache-new,mode=max"]
  network = ["host"]
}

target "github" {
  inherits = ["common_agent"]
  dockerfile = "./agents/github/Dockerfile"
  tags = ["rover-agent:local-github"]
  args = {
    versionGithubRunner = versionGithubRunner
    versionRover = "rover:local"
  }
}

target "azdo" {
  inherits = ["common_agent"]
  dockerfile = "./agents/azure_devops/Dockerfile"
  tags = ["rover-agent:local-azdo"]
  args = {
    versionAzdo = versionAzdo
    versionRover = "rover:local"
  }
}

target "tfc" {
  inherits = ["common_agent"]
  dockerfile = "./agents/tfc/Dockerfile"
  tags = ["rover-agent:local-tfc"]
  args = {
    versionTfc = versionTfc
    versionRover = "rover:local"
  }
}

target "gitlab" {
  inherits = ["common_agent"]
  dockerfile = "./agents/gitlab/Dockerfile"
  tags = ["rover-agent:local-gitlab"]
  args = {
    versionRover = "rover:local"
  }
}
