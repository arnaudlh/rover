group "rover_agents" {
  targets = ["github", "tfc", "azdo", "gitlab"]
}

target "common" {
  context = "."
  args = {
    USERNAME = "vscode"
  }
  platforms = ["linux/amd64"]
  output = ["type=docker"]
}

target "github" {
  inherits = ["common"]
  dockerfile = "./agents/github/Dockerfile"
  tags = ["rover-agent:github"]
}

target "azdo" {
  inherits = ["common"]
  dockerfile = "./agents/azure_devops/Dockerfile"
  tags = ["rover-agent:azdo"]
}

target "tfc" {
  inherits = ["common"]
  dockerfile = "./agents/tfc/Dockerfile"
  tags = ["rover-agent:tfc"]
}

target "gitlab" {
  inherits = ["common"]
  dockerfile = "./agents/gitlab/Dockerfile"
  tags = ["rover-agent:gitlab"]
}
