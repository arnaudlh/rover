Describe 'init.sh'
  Include spec_helper.sh
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

  Describe "init"
    # Mock Azure CLI commands
    az() {
      case "$1" in
        "group")
          case "$2" in
            "list")
              if [ ! -z "${mock_group_list}" ]; then
                echo "${mock_group_list}"
              else
                echo "[]"
              fi
              return 0
              ;;
            "create")
              echo "/subscriptions/123/resourceGroups/test-launchpad"
              return 0
              ;;
            "wait")
              echo "Operation completed"
              return 0
              ;;
            "delete")
              echo "Deleted"
              return 0
              ;;
            "wait")
              echo "Operation completed"
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
                  echo "/subscriptions/123/resourceGroups/test-rg/providers/Microsoft.Storage/storageAccounts/st123"
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
              echo "/subscriptions/123/resourceGroups/test-rg/providers/Microsoft.KeyVault/vaults/kv123"
              return 0
              ;;
            "secret")
              echo '{"id": "secret1"}'
              return 0
              ;;
          esac
          ;;
        "role")
          echo '{"id": "role1"}'
          return 0
          ;;
        "account")
          echo '{"tenantId": "tenant123"}'
          return 0
          ;;
      esac
      return 0
    }

    Context "Resource creation"
      setup() {
        # Core environment variables
        export TF_VAR_environment="test"
        export TF_VAR_level="level0"
        export tf_command=""
        export TF_VAR_tfstate_subscription_id="sub123"
        export location="eastus"
        export TF_VAR_workspace="default"
        export TF_DATA_DIR="/tmp/test"
        
        # Azure authentication
        export ARM_CLIENT_ID="test-client"
        export ARM_CLIENT_SECRET="test-secret"
        export ARM_SUBSCRIPTION_ID="sub123"
        export ARM_TENANT_ID="tenant123"
        export TF_VAR_tenant_id="tenant123"
        
        # Resource naming
        export TF_VAR_tfstate_container_name="tfstate"
        export TF_VAR_tfstate_key="test.tfstate"
        export TF_VAR_logged_user_objectId="user123"
        export TF_VAR_landingzone_name="test-launchpad"
        export TF_VAR_random_length="5"
        export TF_VAR_prefix="test"
        
        # Clear mocks
        unset mock_group_list

        # Create required directories
        mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
      }

      BeforeEach 'setup'

      It 'should create new resource group when none exists'
        When call init
        The output should include "Creating resource group: test-launchpad"
        The output should include "...created"
        The status should eq 0
      End

      It 'should skip creation when resource group exists'
        export mock_group_list='[{"name": "test-rg"}]'
        When call init
        The output should include "Launchpad already deployed"
      End

      It 'should handle clean command'
        export tf_command="--clean"
        export mock_group_list='[{"name": "test-rg"}]'
        When call init
        The output should include "Deleting launchpad"
      End
    End

    Context "Storage account management"
      setup() {
        export TF_VAR_environment="test"
        export TF_VAR_workspace="default"
        export location="eastus"
        export TF_VAR_level="level0"
        export TF_VAR_tfstate_subscription_id="sub123"
        export TF_VAR_landingzone_name="test-launchpad"
      }

      BeforeEach 'setup'

      It 'should create storage account with valid name'
        When call storage_account "test-rg" "eastus"
        The output should include "Creating storage account: st"
        The output should include "stg created"
        The output should include "role"
        The status should eq 0
      End
    End

    Context "KeyVault management"
      setup() {
        export TF_VAR_environment="test"
        export TF_VAR_tfstate_subscription_id="sub123"
        export location="eastus"
      }

      BeforeEach 'setup'

      It 'should create keyvault when none exists'
        When call keyvault "test-rg" "eastus"
        The output should include "Creating keyvault: "
        The output should include "...created"
        The status should eq 0
      End
    End
  End
End
