check_github_session() {
  # Check GitHub token first
  if [ -z "${GITHUB_TOKEN}" ]; then
    echo "GITHUB_TOKEN not set" >&2
    return 1
  fi
  
  # Check GitHub authentication
  if ! gh auth status >/dev/null 2>&1 || [ "${mock_auth_error}" = "true" ]; then
    echo "Error: Not authenticated with GitHub" >&2
    return 1
  fi

  url=$(git config --get remote.origin.url)
  export git_org_project=$(echo "$url" | sed -e 's#^https://github.com/##; s#^git@github.com:##; s#.git$##')
  export git_project=$(basename -s .git $(git config --get remote.origin.url))
  if ! project=$(gh api "repos/${git_org_project}" 2>/dev/null | jq -r .id); then
    error ${LINENO} "Failed to access GitHub repository ${git_org_project}" 1
    return 1
  fi
  if ! export GITOPS_SERVER_URL=$(gh api "repos/${git_org_project}" 2>/dev/null | jq -r .svn_url); then
    error ${LINENO} "Failed to get repository URL for ${git_org_project}" 1
    return 1
  fi
  debug "${project}"
  
  verify_github_secret "actions" "BOOTSTRAP_TOKEN"

  if [ ! -v ${CODESPACES} ]; then
    verify_github_secret "codespaces" "GH_TOKEN"
  fi

  # Show full auth status at the end
  gh auth status
}

verify_git_settings(){
  information "@call verify_git_settings for ${1}"

  command=${1}
  eval ${command}

  RETURN_CODE=$?
  if [ $RETURN_CODE != 0 ]; then
      error ${LINENO} "You need to set a value for ${command} before running the rover bootstrap." $RETURN_CODE
  fi
}

verify_github_secret() {
  information "@call verify_github_secret for ${1}/${2}"

  application=${1}
  secret_name=${2}

  gh secret list -a ${application} | grep "${secret_name}"

  RETURN_CODE=$?

  echo "return code ${RETURN_CODE}"

  set -e
  if [ $RETURN_CODE != 0 ]; then
      error ${LINENO} "You need to set the ${application}/${secret_name} in your project as per instructions in the documentation." $RETURN_CODE
  fi
}

register_github_secret() {
  debug "@call register_github_secret for ${1}"

# ${1} secret name
# ${2} secret value

  gh secret set "${1}" --body "${2}"

}
