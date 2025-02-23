Describe 'azure_ad.sh'
  # Mock jq command
  jq() {
    case "$1" in
      "-r")
        case "$2" in
          ".id")
            echo "app123"
            ;;
          ".appId")
            echo "client123"
            ;;
          ".value[] | select(.displayName == \"Privileged Role Administrator\") | .id")
            echo "role123"
            ;;
          *)
            echo "null"
            ;;
        esac
        ;;
      *)
        echo "null"
        ;;
    esac
  }
  export -f jq

  # Mock az command before including source files
  az() {
    if [ "${mock_error}" = "true" ]; then
      case "$1" in
        "ad")
          case "$2" in
            "signed-in-user")
              echo "Error getting user object ID" >&2
              return 1
              ;;
            "app")
              if [ "$3" = "create" ]; then
                echo "Error creating Azure AD application" >&2
                return 1
              fi
              if [ "$3" = "list" ]; then
                echo "[]"
                return 0
              fi
              ;;
            "sp")
              if [ "$3" = "create" ]; then
                echo "Error creating service principal" >&2
                return 1
              fi
              ;;
          esac
          ;;
        "rest")
          if [ "$2" = "--method" ] && [ "$3" = "post" ] && [ "$4" = "--url" ] && [ "$5" = "/providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01" ]; then
            return 0
          fi
          ;;
      esac
      return 1
    fi

    # Normal flow when mock_error is not set
    if [ "$1" = "ad" ] && [ "$2" = "signed-in-user" ] && [ "$3" = "show" ] && \
       [ "$4" = "--query" ] && [ "$5" = "id" ] && [ "$6" = "-o" ] && [ "$7" = "tsv" ] && [ "$8" = "--only-show-errors" ]; then
      echo "user123"
      return 0
    fi

    if [ "$1" = "rest" ]; then
      if [ "$2" = "--method" ] && [ "$3" = "post" ] && [ "$4" = "--url" ] && [ "$5" = "/providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01" ]; then
        return 0
      fi
      if [ "$2" = "--method" ] && [ "$3" = "Get" ] && [ "$4" = "--uri" ]; then
        case "$5" in
          *"/directoryRoleTemplates")
            echo '{"value": [{"id": "role123", "displayName": "Privileged Role Administrator"}]}'
            ;;
          *"/directoryRoles")
            echo '{"value": [{"id": "role123", "displayName": "Privileged Role Administrator"}]}'
            ;;
          *)
            echo "{}"
            ;;
        esac
        return 0
      fi
      if [ "$2" = "--method" ] && [ "$3" = "POST" ] && [ "$4" = "--uri" ] && [[ "$5" == *"/members/\$ref" ]]; then
        return 0
      fi
      return 0
    fi

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
  export -f az

  Include spec/support/spec_helper.sh
  Include scripts/lib/logger.sh
  Include scripts/functions.sh
  Include scripts/lib/azure_ad.sh

  setup() {
    setup_test_env
    export script_path="$PWD"

    # Mock logger functions to prevent extra output
    debug() { :; }
    error() { 
      local line_number=$1
      local message=$2
      echo "$message" >&2
    }
    warning() { :; }
    information() { echo "$1"; }
    success() { echo "$1"; }
    export -f debug error warning information success

    # Reset mock_error flag
    unset mock_error
  }

  cleanup() {
    unset mock_error
    unset app_name
    unset subscription_id
    unset tenant_id
  }

  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe "get_logged_in_user_object_id"
    It 'should return user object ID successfully'
      When call get_logged_in_user_object_id
      The output should equal "user123"
      The status should eq 0
    End

    It 'should handle Azure CLI error'
      export mock_error=true
      When call get_logged_in_user_object_id
      The status should eq 1
      The stderr should include "Error getting user object ID"
    End
  End

  Describe "create_federated_identity"
    BeforeEach 'export subscription_id="sub123" tenant_id="tenant123"'

    It 'should create app and service principal successfully'
      When call create_federated_identity test-app
      The output should include " - application created."
      The output should include " - service principal created."
      The status should eq 0
    End

    Describe 'error handling'
      setup() {
        setup_test_env
        mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
        export script_path="$PWD"

        # Mock logger functions
        debug() { :; }
        error() { echo "$2" >&2; }
        warning() { :; }
        information() { :; }
        success() { :; }
        export -f debug error warning information success
      }
      cleanup() {
        cleanup_test_env
        rm -rf "${TF_DATA_DIR}/tfstates"
      }
      BeforeEach 'setup'
      AfterEach 'cleanup'

      Context 'app creation'
        setup_app_error() {
          az() {
            case "$1" in
              "ad")
                case "$2" in
                  "app")
                    case "$3" in
                      "create")
                        echo "Error creating Azure AD application" >&2
                        return 1
                        ;;
                      "list")
                        echo "[]"
                        return 0
                        ;;
                    esac
                    ;;
                esac
                ;;
              "rest")
                if [ "$2" = "--method" ] && [ "$3" = "post" ] && [ "$4" = "--url" ] && [ "$5" = "/providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01" ]; then
                  return 0
                fi
                ;;
            esac
            return 0
          }
          export -f az
        }

        It 'should handle app creation failure'
          setup_app_error
          When run create_federated_identity test-app
          The stderr should include "Failed to create Azure AD application"
          The status should be failure
        End
      End

      Context 'service principal creation'
        setup_sp_error() {
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
                        echo "Error creating service principal" >&2
                        return 1
                        ;;
                    esac
                    ;;
                esac
                ;;
              "rest")
                if [ "$2" = "--method" ] && [ "$3" = "post" ] && [ "$4" = "--url" ] && [ "$5" = "/providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01" ]; then
                  return 0
                fi
                ;;
            esac
            return 0
          }
          export -f az
        }

        It 'should handle service principal creation failure'
          setup_sp_error
          When run create_federated_identity test-app
          The stderr should include "Failed to create service principal"
          The status should be failure
        End
      End
    End
  End
End
