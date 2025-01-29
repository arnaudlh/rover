Describe 'tool versions'
  # Helper function for skipping tests when tools are not available
  Skip.If() {
    local message="$1"
    shift
    if ! "$@" >/dev/null 2>&1; then
      Skip "$message"
      return 1
    fi
    return 0
  }
  Describe 'terraform'
    It 'has correct version installed'
      Skip.If "terraform not found" command -v terraform
      When call terraform version
      The status should be success
      The output should include '1.10.5'
    End
  End

  Describe 'security tools'
    It 'has correct tfsec version'
      Skip.If "tfsec not found" command -v tfsec
      When call tfsec --version
      The status should be success
      The output should include '1.28.13'
    End

    It 'has correct terrascan version'
      Skip.If "terrascan not found" command -v terrascan
      When call terrascan version
      The status should be success
      The output should include '1.19.9'
    End

    It 'has correct tflint version'
      Skip.If "tflint not found" command -v tflint
      When call tflint --version
      The status should be success
      The output should include '0.55.0'
    End
  End
End
