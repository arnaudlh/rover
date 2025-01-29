Skip.If() {
  local message="$1"
  shift
  if ! "$@"; then
    Skip "$message"
    return 1
  fi
  return 0
}
