Describe 'azure_ad.sh'
  Include spec/support/spec_helper.sh
  Include scripts/lib/azure_ad.sh
  Include scripts/lib/logger.sh
  Include scripts/lib/functions.sh
  
  # Mock logger functions to prevent extra output
  debug() { :; }
  error() { echo "Error: $2" >&2; }
  warning() { :; }
  information() { :; }
  success() { :; }

  setup() {
    setup_test_env
    export script_path="$PWD"
  }
  cleanup() {
    cleanup_test_env
  }
  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe "get_logged_in_user_object_id"
    setup() {
      # Mock Azure CLI commands
      az() {
        case "$1" in
          "ad")
            case "$2" in
              "signed-in-user")
                case "$3" in
                  "show")
                    if [ "${mock_error}" = "true" ]; then
                      return 1
                    fi
                    # Handle --query id -o tsv --only-show-errors flags
                    if [[ "$1" = "ad" && "$2" = "signed-in-user" && "$3" = "show" && "$4" = "--query" && "$5" = "id" && "$6" = "-o" && "$7" = "tsv" && "$8" = "--only-show-errors" ]]; then
                      echo "user123"
                    else
                      echo '{"id": "user123", "userPrincipalName": "test@example.com"}'
                    fi
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

    It 'should return user object ID successfully'
      When call get_logged_in_user_object_id
      The output should equal "user123"
      The status should eq 0
    End

    It 'should handle Azure CLI error'
      export mock_error="true"
      When call get_logged_in_user_object_id
      The status should eq 1
      The stderr should include "Error getting user object ID"
    End
  End

  Describe "create_federated_identity"
    setup() {
      # Mock Azure CLI commands
      az() {
        case "$1" in
          "ad")
            case "$2" in
              "app")
                case "$3" in
                  "create")
                    echo '{"id": "app123", "appId": "client123"}'
                    return 0
                    ;;
                  "list")
                    echo "[]"
                    return 0
                    ;;
                esac
                ;;
              "sp")
                case "$3" in
                  "create")
                    echo '{"id": "sp123", "appId": "client123"}'
                    return 0
                    ;;
                esac
                ;;
            esac
            ;;
          "role")
            case "$2" in
              "assignment")
                case "$3" in
                  "create")
                    echo '{"id": "role123"}'
                    return 0
                    ;;
                esac
                ;;
            esac
            ;;
        esac
        return 0
      }
      export app_name="test-app"
      export subscription_id="sub123"
      export tenant_id="tenant123"
    }

    BeforeEach 'setup'

    It 'should create app and service principal successfully'
      When call create_federated_identity
      The output should include "Creating Azure AD application"
      The output should include "Creating service principal"
      The output should include "Assigning role"
      The status should eq 0
    End

    It 'should handle app creation failure'
      az() {
        case "$1" in
          "ad")
            case "$2" in
              "app")
                return 1
                ;;
            esac
            ;;
        esac
        return 0
      }
      When call create_federated_identity
      The status should eq 1
      The stderr should include "Error creating Azure AD application"
    End

    It 'should handle service principal creation failure'
      az() {
        case "$1" in
          "ad")
            case "$2" in
              "app")
                echo '{"id": "app123", "appId": "client123"}'
                return 0
                ;;
              "sp")
                return 1
                ;;
            esac
            ;;
        esac
        return 0
      }
      When call create_federated_identity
      The status should eq 1
      The stderr should include "Error creating service principal"
    End
  End
End
