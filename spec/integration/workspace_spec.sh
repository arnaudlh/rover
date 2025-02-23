Describe 'workspace management'
  Include spec_helper.sh
  Include ./terraform.sh
  Include ./init.sh
  Include ./logger.sh
  Include ./functions.sh

  setup() {
    setup_test_env
    mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
    export script_path="$PWD"
  }
  cleanup() {
    cleanup_test_env
    rm -rf "${TF_DATA_DIR}/tfstates"
  }
  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe "workspace creation"
    setup() {
      # Mock Azure CLI commands
      az() {
        case "$1" in
          "group")
            case "$2" in
              "list")
                echo "[]"
                return 0
                ;;
              "create")
                echo "/subscriptions/${TF_VAR_tfstate_subscription_id}/resourceGroups/${TF_VAR_environment}-launchpad"
                return 0
                ;;
              "wait")
                echo "Resource group created"
                return 0
                ;;
            esac
            ;;
          "storage")
            case "$2" in
              "account")
                case "$3" in
                  "list")
                    echo "[]"
                    return 0
                    ;;
                  "create")
                    echo "/subscriptions/${TF_VAR_tfstate_subscription_id}/resourceGroups/${TF_VAR_environment}-launchpad/providers/Microsoft.Storage/storageAccounts/st${TF_VAR_environment}123"
                    return 0
                    ;;
                  "check-name")
                    echo '{"nameAvailable": true}'
                    return 0
                    ;;
                esac
                ;;
              "container")
                echo '{"created": true}'
                return 0
                ;;
            esac
            ;;
          "keyvault")
            case "$2" in
              "list")
                echo "[]"
                return 0
                ;;
              "create")
                echo "/subscriptions/${TF_VAR_tfstate_subscription_id}/resourceGroups/${TF_VAR_environment}-launchpad/providers/Microsoft.KeyVault/vaults/kv${TF_VAR_environment}123"
                return 0
                ;;
              "secret")
                echo '{"id": "secret1"}'
                return 0
                ;;
            esac
            ;;
        esac
        return 0
      }

      # Mock Terraform commands
      terraform() {
        case "$1" in
          "-chdir=${landingzone_name}")
            case "$2" in
              "init")
                echo "Terraform has been successfully initialized!"
                return 0
                ;;
              "workspace")
                case "$3" in
                  "new")
                    echo "Created and switched to workspace \"${4}\"!"
                    return 0
                    ;;
                  "select")
                    echo "Switched to workspace \"${4}\"!"
                    return 0
                    ;;
                esac
                ;;
            esac
            ;;
        esac
        return 0
      }
    }

    BeforeEach 'setup'

    Context "Full workspace creation flow"
      It 'should create workspace with all resources'
        export TF_VAR_environment="test"
        export TF_VAR_workspace="testws"
        export TF_VAR_level="level0"
        export landingzone_name="test-landingzone"
        
        When call create_workspace
        The output should include "Creating resource group: ${TF_VAR_environment}-launchpad"
        The output should include "Creating storage account: st${TF_VAR_environment}"
        The output should include "Creating keyvault: kv${TF_VAR_environment}"
        The output should include "Created and switched to workspace \"${TF_VAR_workspace}\""
        The status should eq 0
      End

      It 'should handle existing workspace'
        terraform() {
          case "$1" in
            "-chdir=${landingzone_name}")
              case "$2" in
                "workspace")
                  case "$3" in
                    "new")
                      return 1
                      ;;
                    "select")
                      echo "Switched to workspace \"${4}\"!"
                      return 0
                      ;;
                  esac
                  ;;
              esac
              ;;
          esac
          return 0
        }

        export TF_VAR_workspace="existing"
        When call create_workspace
        The output should include "Switched to workspace \"${TF_VAR_workspace}\""
        The status should eq 0
      End
    End

    Context "State file setup"
      It 'should initialize state file'
        When call init_state_file
        The output should include "Terraform has been successfully initialized!"
        The status should eq 0
      End

      It 'should handle state file initialization failure'
        terraform() { return 1; }
        When call init_state_file
        The status should eq 1
        The stderr should include "Error initializing state file"
      End
    End

    Context "Cleanup procedures"
      It 'should clean up workspace resources'
        export tf_command="--clean"
        When call cleanup_workspace
        The output should include "Deleting workspace resources"
        The status should eq 0
      End

      It 'should handle cleanup failures'
        export tf_command="--clean"
        terraform() { return 1; }
        When call cleanup_workspace
        The status should eq 1
        The stderr should include "Error cleaning up workspace"
      End
    End
  End
End
