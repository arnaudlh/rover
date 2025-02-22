Describe 'parse_parameters.sh'
  Include scripts/functions.sh
  Include scripts/lib/logger.sh
  Include scripts/lib/parse_parameters.sh

  Describe "parse_parameters"
    # Mock functions
    error() {
      local parent_lineno="$1"
      local message="$2"
      >&2 echo "Error line:${parent_lineno}: message:${message}"
    }

    debug() {
      echo "Debug: $1"
    }

    set_log_severity() {
      export LOG_SEVERITY="${1}"
    }

    parameter_value() {
      echo "${2}"
    }

    Context "Basic command parsing"
      setup() {
        unset caf_command
        unset landingzone_name
        unset TF_VAR_tf_name
      }

      BeforeEach 'setup'

      It 'should handle login command'
        When call parse_parameters login
        The variable caf_command should eq "login"
      End

      It 'should handle logout command'
        When call parse_parameters logout
        The variable caf_command should eq "logout"
      End

      It 'should handle workspace command'
        When call parse_parameters workspace
        The variable caf_command should eq "workspace"
      End
    End

    Context "Parameter validation"
      It 'should validate tfstate extension'
        When call parse_parameters -tfstate invalid.txt
        The error should include "tfstate name extension must be .tfstate"
        The status should eq 50
      End

      It 'should accept valid tfstate extension'
        When call parse_parameters -tfstate valid.tfstate
        The variable TF_VAR_tf_name should eq "valid.tfstate"
        The variable TF_VAR_tf_plan should eq "valid.tfplan"
      End
    End

    Context "Environment variables"
      setup() {
        unset TF_VAR_environment
        unset TF_VAR_workspace
        unset debug_mode
      }

      BeforeEach 'setup'

      It 'should set environment variable'
        When call parse_parameters -env test
        The variable TF_VAR_environment should eq "test"
      End

      It 'should set workspace variable'
        When call parse_parameters -w myworkspace
        The variable TF_VAR_workspace should eq "myworkspace"
      End

      It 'should enable debug mode'
        When call parse_parameters -d
        The variable debug_mode should eq "true"
      End
    End
  End
End
