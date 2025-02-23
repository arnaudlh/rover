Describe 'github.com.sh'
  Include spec/support/spec_helper.sh
  Include scripts/lib/github.com.sh
  Include scripts/lib/logger.sh
  Include scripts/lib/functions.sh

  setup() {
    setup_test_env
    export script_path="$PWD"
  }
  cleanup() {
    cleanup_test_env
  }
  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe "check_github_session"
    setup() {
      # Mock GitHub CLI commands
      gh() {
        case "$1" in
          "auth")
            case "$2" in
              "status")
                if [ "${mock_auth_error}" = "true" ]; then
                  return 1
                fi
                echo "Logged in to github.com as testuser"
                return 0
                ;;
            esac
            ;;
          "repo")
            case "$2" in
              "view")
                if [ "${mock_repo_error}" = "true" ]; then
                  return 1
                fi
                echo "owner/repo"
                return 0
                ;;
            esac
            ;;
        esac
        return 0
      }
    }

    BeforeEach 'setup'

    Context "Authentication verification"
      It 'should verify GitHub authentication successfully'
        When call check_github_session
        The output should include "Logged in to github.com"
        The status should eq 0
      End

      It 'should handle authentication failure'
        export mock_auth_error="true"
        When call check_github_session
        The status should eq 1
        The stderr should include "Error: Not authenticated with GitHub"
      End
    End

    Context "Repository validation"
      It 'should verify repository access successfully'
        When call check_github_session "owner/repo"
        The output should include "owner/repo"
        The status should eq 0
      End

      It 'should handle repository access failure'
        export mock_repo_error="true"
        When call check_github_session "owner/repo"
        The status should eq 1
        The stderr should include "Error: Repository not accessible"
      End
    End
  End

  Describe "verify_github_secret"
    setup() {
      # Mock GitHub CLI commands
      gh() {
        case "$1" in
          "secret")
            case "$2" in
              "list")
                if [ "${mock_secret_error}" = "true" ]; then
                  return 1
                fi
                echo "test_secret"
                return 0
                ;;
            esac
            ;;
        esac
        return 0
      }
    }

    BeforeEach 'setup'

    Context "Secret validation"
      It 'should verify secret exists successfully'
        When call verify_github_secret "test_secret"
        The output should include "test_secret"
        The status should eq 0
      End

      It 'should handle missing secret'
        export mock_secret_error="true"
        When call verify_github_secret "missing_secret"
        The status should eq 1
        The stderr should include "Error: Secret not found"
      End
    End

    Context "Error handling"
      It 'should handle GitHub CLI errors'
        gh() { return 1; }
        When call verify_github_secret "test_secret"
        The status should eq 1
        The stderr should include "Error accessing GitHub secrets"
      End
    End
  End
End
