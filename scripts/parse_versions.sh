#!/usr/bin/env bash
set -e

MANIFEST_FILE="$(dirname "$0")/../versions/manifest.json"
JQ_CMD="jq -r"

get_tool_version() {
  local tool=$1
  if [ "$tool" = "terraform" ]; then
    get_terraform_version
  elif [ "$tool" = "docker-compose" ]; then
    $JQ_CMD ".base.tools.docker_compose" "$MANIFEST_FILE"
  elif [ "$tool" = "golang" ]; then
    version=$($JQ_CMD ".base.tools.golang" "$MANIFEST_FILE")
    echo "$version"
  else
    $JQ_CMD ".base.tools.$tool" "$MANIFEST_FILE"
  fi
}

get_agent_version() {
  local agent=$1
  case "$agent" in
    "github") $JQ_CMD ".agents.github_runner" "$MANIFEST_FILE" ;;
    *) $JQ_CMD ".agents.$agent" "$MANIFEST_FILE" ;;
  esac
}

get_terraform_version() {
  # Get the latest stable version (excluding alpha/beta)
  $JQ_CMD '.terraform.versions[] | select(test("^\\d+\\.\\d+\\.\\d+$"))' "$MANIFEST_FILE" | sort -V | tail -n1
}

# Verify manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
  echo "Error: Manifest file not found at $MANIFEST_FILE" >&2
  exit 1
fi

case "$1" in
  "tool") 
    if [ -z "$2" ]; then
      echo "Error: Tool name required" >&2
      exit 1
    fi
    version=$(get_tool_version "$2")
    if [ -z "$version" ]; then
      echo "Error: Version not found for tool $2" >&2
      exit 1
    fi
    echo "$version"
    ;;
  "agent")
    if [ -z "$2" ]; then
      echo "Error: Agent name required" >&2
      exit 1
    fi
    version=$(get_agent_version "$2")
    if [ -z "$version" ]; then
      echo "Error: Version not found for agent $2" >&2
      exit 1
    fi
    echo "$version"
    ;;
  "terraform") get_terraform_version ;;
  *) echo "Usage: $0 [tool|agent|terraform] [name]" >&2; exit 1 ;;
esac
