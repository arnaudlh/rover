#!/usr/bin/env bash
set -e

MANIFEST_FILE="versions/manifest.json"
JQ_CMD="jq -r"

get_tool_version() {
  local tool=$1
  $JQ_CMD ".base.tools.$tool" "$MANIFEST_FILE"
}

get_agent_version() {
  local agent=$1
  $JQ_CMD ".agents.$agent" "$MANIFEST_FILE"
}

get_terraform_versions() {
  $JQ_CMD '.terraform.versions[]' "$MANIFEST_FILE"
}

case "$1" in
  "tool") get_tool_version "$2" ;;
  "agent") get_agent_version "$2" ;;
  "terraform") get_terraform_versions ;;
  *) echo "Usage: $0 [tool|agent|terraform] [name]" >&2; exit 1 ;;
esac
