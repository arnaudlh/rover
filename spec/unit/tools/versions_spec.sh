Describe 'tool versions'
  Describe 'terraform'
    It 'has correct version installed'
      When call terraform version
      The status should be success
      The output should include '1.10.5'
    End
  End

  Describe 'security tools'
    It 'has correct tfsec version'
      When call tfsec --version
      The status should be success
      The output should include '1.28.13'
    End

    It 'has correct terrascan version'
      When call terrascan version
      The status should be success
      The output should include '1.19.9'
    End

    It 'has correct tflint version'
      When call tflint --version
      The status should be success
      The output should include '0.55.0'
    End
  End
End
