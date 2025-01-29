Describe 'cd.sh'
  Include scripts/cd.sh
  Include scripts/lib/logger.sh
  Include scripts/functions.sh

  Describe "verify_cd_parameters"
    #Function Mocks

    escape () {
      echo "Escape code: $1"
    }

    error() {
        # local parent_lineno="$1"
        # local message="$2"
        # >&2 echo "Error line:${parent_lineno}: message:${message} status :${code}"
        # return ${code}
        echo "here*******"
    }

    Context "run action"
      setup() {
        export TF_VAR_environment="demo"
        export cd_action="run"
      }
      BeforeEach 'setup'

      It 'should handle known cd run'
        When call verify_cd_parameters
        The output should include 'Found valid cd action - terraform run'
        The status should eq 0
      End
    End

    Context "apply action"
      setup() {
        export TF_VAR_environment="demo"
        export cd_action="apply"
      }
      BeforeEach 'setup'

      It 'should handle known cd apply'
        When call verify_cd_parameters
        The output should include 'Found valid cd action - terraform apply'
        The status should eq 0
      End
    End

    Context "plan action"
      setup() {
        export TF_VAR_environment="demo"
        export cd_action="plan"
      }
      BeforeEach 'setup'

      It 'should handle known cd plan'
        When call verify_cd_parameters
        The output should include 'Found valid cd action - terraform plan'
        The status should eq 0
      End
    End

    Context "test action"
      setup() {
        export TF_VAR_environment="demo"
        export cd_action="test"
      }
      BeforeEach 'setup'

      It 'should handle known cd test'
        When call verify_cd_parameters
        The output should include 'Found valid cd action test'
        The status should eq 0
      End
    End

    Context "rover deploy help"
      setup() {
        export TF_VAR_environment="demo"
        export cd_action="-h"
      }
      BeforeEach 'setup'

      It 'should show help usage'
        When call verify_cd_parameters
        The output should include '@Verifying cd parameters'
        The error should include 'Usage:'
        The error should include 'rover deploy <action> <flags>'
        The status should eq 0
      End
    End

    Context "rover cd run help"
      setup() {
        export TF_VAR_environment="demo"
        export cd_action="run"
        export PARAMS="-h "
      }
      BeforeEach 'setup'

      It 'should show help usage'
        When call verify_cd_parameters
        The output should include '@Verifying cd parameters'
        The error should include 'Usage:'
        The error should include 'rover deploy <action> <flags>'
        The status should eq 0
      End
    End

    Context "invalid action"
      setup() {
        export TF_VAR_environment="demo"
        export cd_action="bad_action"
      }

      BeforeEach 'setup'

      It 'should handle show an error message for invalid cd actions'
        When call verify_cd_parameters
        The output should include '@Verifying cd parameters'
        The error should include 'Invalid cd action bad_action'
        The output should include 'Escape code: 1'
      End
    End

    Context "no environment set"
      setup() {
        unset TF_VAR_environment
        export cd_action="run"
      }

      BeforeEach 'setup'

      It 'should default to sandpit environment'
        When call verify_cd_parameters
        The output should include '@Verifying cd parameters'
        The variable TF_VAR_environment should eq 'sandpit'
        The status should eq 0
      End
    End

  End
End
