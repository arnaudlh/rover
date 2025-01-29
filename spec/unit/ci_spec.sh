Describe 'ci.sh'
  Include scripts/lib/task.sh
  Include scripts/ci.sh
  Include scripts/functions.sh

  Describe "verify_ci_parameters"
    #Function Mocks
    error() {
        local parent_lineno="$1"
        local message="$2"
        >&2 echo "Error line:${parent_lineno}: message:${message} status :${code}"
        return ${code}
    }

    Context "Basic CI Parameters"
      setup() {
        export TF_VAR_environment="demo"
        export TF_VAR_level="level1"
      }
      BeforeEach 'setup'

      It 'should accept valid environment and level parameters'
        When call verify_ci_parameters
        The output should eq '@Verifying ci parameters'
        The error should eq ''
        The status should eq 0
      End
    End

    Context "No Environment Set"
      setup() {
        unset TF_VAR_environment
        export TF_VAR_level="level1"
      }
      BeforeEach 'setup'

      It 'should default to sandpit environment'
        When call verify_ci_parameters
        The output should eq '@Verifying ci parameters'
        The error should eq ''
        The status should eq 0
        The variable TF_VAR_environment should eq 'sandpit'
      End
    End

    Context "Tasks Registered"
      Describe "tasks registered"
        setup() {
          export TF_VAR_environment="demo"
          export TF_VAR_level="level1"

          # create mock dirs
          mkdir -p ./spec/harness/landingzones/level1
          touch ./spec/harness/landingzones/level1/main.tf

          mkdir -p ./spec/harness/configuration/level1
          touch ./spec/harness/configuration/level1/configuration.tfvars
        }

        teardown(){
          rm -rf ./spec/harness/configuration
          rm -rf ./spec/harness/landingzones
        }

        BeforeEach 'setup'
        AfterEach 'teardown'

        It 'should return no errors if ci tasks are registered'
          When call verify_ci_parameters
          The output should eq '@Verifying ci parameters'
          The error should eq ''
          The status should eq 0
        End
      End

      Describe "single task execution - success"
        setup() {
          CI_TASK_CONFIG_FILE_LIST=()
          REGISTERED_CI_TASKS=()
          export TF_VAR_environment="demo"
          export TF_VAR_level="level1"
          export ci_task_name='task1'
          export CI_TASK_DIR='spec/harness/ci_tasks/'
          register_ci_tasks
        }

        Before 'setup'

        It 'should return no errors if ci tasks are registered'
          When call verify_ci_parameters
          The error should eq ''
          The output should include '@Verifying ci parameters'
          The status should eq 0
        End
      End

      Describe "single task execution - error"
        setup() {
          CI_TASK_CONFIG_FILE_LIST=()
          REGISTERED_CI_TASKS=()
          export TF_VAR_environment="demo"
          export TF_VAR_level="level1"
          export ci_task_name='task'
          export CI_TASK_DIR='spec/harness/ci_tasks/'
          register_ci_tasks
        }

        Before 'setup'

        It 'should return an error if ci task name is not registered'
          When call verify_ci_parameters
          The error should include 'task is not a registered ci command!'
          The output should include '@Verifying ci parameters'
          The status should eq 1
        End
      End
    End

  End

  Describe "execute_ci_actions"

    Context "Happy Path Validation"

      run_task() {
        echo "run_task arguments: $@";
        return 0
      }

      setup() {
        export TF_VAR_environment="demo"
        export TF_VAR_level='all'
      }

      BeforeEach 'setup'

      It 'should return no errors when executing all tasks'
        When call execute_ci_actions
        The output should include "@Starting CI tools execution"
        The output should include "All CI tasks have run successfully."
        The error should eq ''
        The status should eq 0
      End

    End

  End

  Describe "single level test - execute_ci_actions"

    Context "Single Level Test - Invalid Level"

      #Function Mocks
      error() {
          local parent_lineno="$1"
          local message="$2"
          >&2 echo "Error line:${parent_lineno}: message:${message} status :${code}"
          return ${code}
      }

      setup() {
        export TF_VAR_environment="demo"
        export TF_VAR_level='invalid_level'
      }

      BeforeEach 'setup'

      It 'should return an error when executing because the level is invalid'
        When call execute_ci_actions
        The output should include "@Starting CI tools execution"
        The status should eq 1
      End

    End

  End

  Describe "execute_ci_actions - single level test "

    Context "Single Level Test - Valid Level"

      #Function Mocks
      error() {
          local parent_lineno="$1"
          local message="$2"
          >&2 echo "Error line:${parent_lineno}: message:${message} status :${code}"
          return ${code}
      }

      setup() {
        export TF_VAR_environment="demo"
        export TF_VAR_level='level0'
      }

      BeforeEach 'setup'

      It 'should return no errors when executing all tasks with a valid level'
        When call execute_ci_actions
        The output should include "@Starting CI tools execution"
        The error should eq ''
        The status should eq 0
      End

    End

  End

End
