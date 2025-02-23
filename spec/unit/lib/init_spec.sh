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

    Context "Resource creation"
      setup() {
        # Mock functions
        display_instructions() { echo "Instructions displayed"; }
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
                  echo "/subscriptions/${TF_VAR_tfstate_subscription_id}/resourceGroups/${TF_VAR_environment}-launchpad"
                  return 0
                  ;;
                "wait")
                  case "$3" in
                    "--deleted")
                      echo "Resource group deleted"
                      return 0
                      ;;
                    "--created")
                      echo "Resource group created"
                      return 0
                      ;;
                  esac
                  ;;
                "delete")
                  echo "Deleting resource group"
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
            "role")
              echo '{"id": "role1"}'
              return 0
              ;;
            "ad")
              echo '{"userPrincipalName": "test@example.com"}'
              return 0
              ;;
            "account")
              echo '{"tenantId": "tenant123"}'
              return 0
              ;;
          esac
          return 0
        }
      }

      BeforeEach 'setup'

      It 'should create new resource group when none exists'
        When call init
        The output should include "Creating resource group: ${TF_VAR_environment}-launchpad"
        The output should include "...created"
        The output should include "Creating storage account: st${TF_VAR_environment}"
        The output should include "stg created"
        The output should include "role"
        The output should include "Creating keyvault: kv${TF_VAR_environment}"
        The output should include "...created"
        The output should include "Instructions displayed"
        The status should eq 0
      End

      It 'should skip creation when resource group exists'
        export mock_group_list='[{"name": "${TF_VAR_environment}-launchpad"}]'
        When call init
        The output should include "Launchpad already deployed in"
        The status should eq 0
      End

      It 'should handle clean command when resource group exists'
        export tf_command="--clean"
        export mock_group_list='[{"name": "${TF_VAR_environment}-launchpad"}]'
        When call init
        The output should include "Deleting launchpad caf_environment=${TF_VAR_environment} and caf_tfstate=${TF_VAR_level} in /subscriptions/${TF_VAR_tfstate_subscription_id}/resourceGroups/${TF_VAR_environment}-launchpad"
        The output should include "Launchpad caf_environment=${TF_VAR_environment} and caf_tfstate=${TF_VAR_level} in ${TF_VAR_environment}-launchpad destroyed."
        The status should eq 0
      End

      It 'should handle clean command when resource group does not exist'
        export tf_command="--clean"
        export mock_group_list="[]"
        When call init
        The output should include "Launchpad caf_environment=${TF_VAR_environment} and caf_tfstate=${TF_VAR_level} in /subscriptions/${TF_VAR_tfstate_subscription_id}/resourceGroups/${TF_VAR_environment}-launchpad has been clean-up."
        The status should eq 0
      End
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
        When call storage_account "${TF_VAR_environment}-launchpad" "eastus"
        The output should include "Creating storage account: st${TF_VAR_environment}"
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
        When call keyvault "${TF_VAR_environment}-launchpad" "eastus"
        The output should include "Creating keyvault: kv${TF_VAR_environment}"
        The output should include "...created"
        The status should eq 0
      End
    End
  End
End
