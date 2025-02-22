Describe 'init.sh'
  Include scripts/lib/logger.sh
  Include scripts/lib/init.sh

  Describe "init"
    # Mock Azure CLI commands
    az() {
      case "$1" in
        "group")
          case "$2" in
            "list")
              echo "${mock_group_list:-[]}"
              ;;
            "create")
              echo "/subscriptions/123/resourceGroups/test-rg"
              ;;
            "delete")
              echo "Deleted"
              ;;
            "wait")
              echo "Operation completed"
              ;;
          esac
          ;;
        "storage")
          case "$2" in
            "account")
              case "$3" in
                "list")
                  echo "[]"
                  ;;
                "create")
                  echo "/subscriptions/123/resourceGroups/test-rg/providers/Microsoft.Storage/storageAccounts/st123"
                  ;;
                "check-name")
                  echo '{"nameAvailable": true}'
                  ;;
              esac
              ;;
            "container")
              echo '{"created": true}'
              ;;
          esac
          ;;
        "keyvault")
          case "$2" in
            "list")
              echo "[]"
              ;;
            "create")
              echo "/subscriptions/123/resourceGroups/test-rg/providers/Microsoft.KeyVault/vaults/kv123"
              ;;
            "secret")
              echo '{"id": "secret1"}'
              ;;
          esac
          ;;
        "role")
          echo '{"id": "role1"}'
          ;;
        "account")
          echo '{"tenantId": "tenant123"}'
          ;;
      esac
    }

    Context "Resource creation"
      setup() {
        export TF_VAR_environment="test"
        export TF_VAR_level="level0"
        export tf_command=""
        export TF_VAR_tfstate_subscription_id="sub123"
        export location="eastus"
        unset mock_group_list
      }

      BeforeEach 'setup'

      It 'should create new resource group when none exists'
        When call init
        The output should include "Creating resource group: test-launchpad"
        The output should include "created"
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
      }

      BeforeEach 'setup'

      It 'should create storage account with valid name'
        When call storage_account "test-rg" "eastus"
        The status should eq 0
        The output should include "Creating storage account"
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
        The output should include "Creating keyvault"
        The output should include "created"
      End
    End
  End
End
