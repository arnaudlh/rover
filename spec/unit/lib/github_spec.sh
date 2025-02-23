Describe 'github.com.sh'
  Include spec/support/spec_helper.sh
  Include scripts/lib/logger.sh
  Include scripts/lib/github.com.sh
  Include scripts/functions.sh

  setup() {
    setup_test_env
    export script_path="$PWD"
    export LOG_TO_FILE="false"
    export LOG_LEVEL="INFO"
    export log_folder_path="/tmp/rover_test_logs"
    __log_init__
    set_log_severity "INFO"
    export GITHUB_TOKEN="dummy_token"
    export mock_auth_error="false"
    export mock_repo_error="false"
    export mock_secret_error="false"
    export git_org_project="owner/repo"
    export GH_TOKEN="dummy_token"
    unset CODESPACES
    
    # Create mock bin directory and /usr/bin symlink path
    mkdir -p /tmp/mock_bin/usr/bin
    export PATH="/tmp/mock_bin:$PATH"
    
    # Create mock gh command
    cat > /tmp/mock_bin/gh << 'EOF'
#!/bin/bash
case "$1" in
  "auth")
    case "$2" in
      "status")
        if [ "${mock_auth_error}" = "true" ]; then
          echo "Error: Not authenticated with GitHub" >&2
          return 1
        fi
        echo "github.com"
        echo "✓ Logged in to github.com as testuser"
        echo "- Active account: testuser"
        return 0
        ;;
    esac
    ;;
  "api")
    if [[ "$2" == "repos/owner/repo" ]]; then
      if [ "${mock_repo_error}" = "true" ]; then
        echo "Error: Repository not accessible" >&2
        return 1
      fi
      echo '{"id": 12345, "svn_url": "https://github.com/owner/repo"}'
      return 0
    fi
    ;;
  "secret")
    case "$2" in
      "list")
        if [ "$3" = "-a" ] && [ "$4" = "actions" ]; then
          if [ "${mock_secret_error}" = "true" ]; then
            echo "OTHER_SECRET Updated 2024-02-23"
          else
            echo "BOOTSTRAP_TOKEN Updated 2024-02-23"
          fi
          return 0
        fi
        ;;
    esac
    ;;
  *)
    return 1
    ;;
esac
return 0
EOF
    chmod +x /tmp/mock_bin/gh
    ln -sf $(readlink -f /tmp/mock_bin/gh) /tmp/mock_bin/usr/bin/gh
    
    # Mock git command
    git() {
      case "$1" in
        "config")
          case "$2" in
            "--get")
              if [[ "$3" == "remote.origin.url" ]]; then
                echo "https://github.com/owner/repo.git"
                return 0
              fi
              ;;
          esac
          ;;
        "rev-parse")
          if [[ "$2" == "--show-toplevel" ]]; then
            echo "/home/runner/work/rover/rover"
            return 0
          fi
          ;;
        "status")
          echo "On branch main"
          return 0
          ;;
      esac
      return 0
    }
    export -f git
  }
  cleanup() {
    cleanup_test_env
    rm -rf /tmp/mock_bin
    rm -rf /tmp/rover_test_logs
  }
  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe "check_github_session"
    BeforeEach 'setup'

    Context "Authentication verification"
      It 'should verify GitHub authentication successfully'
        # Mock verify_github_secret function
        verify_github_secret() {
          return 0
        }
        export -f verify_github_secret
        When call check_github_session
        The output should include "Connected to GiHub: repos/owner/repo"
        The output should include "✓ Logged in to github.com"
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
    BeforeEach 'setup'

    Context "Secret validation"
      It 'should verify secret exists successfully'
        When call verify_github_secret "actions" "BOOTSTRAP_TOKEN"
        The output should include "return code 0"
        The status should eq 0
      End

      It 'should handle missing secret'
        export mock_secret_error="true"
        When call verify_github_secret "actions" "BOOTSTRAP_TOKEN"
        The output should include "return code 1"
        The stderr should include "You need to set the actions/BOOTSTRAP_TOKEN in your project as per instructions in the documentation"
        The status should eq 1
      End
    End

    Context "Error handling"
      It 'should handle GitHub CLI errors'
        gh() { return 1; }
        When call verify_github_secret "actions" "BOOTSTRAP_TOKEN"
        The output should include "return code 1"
        The stderr should include "You need to set the actions/BOOTSTRAP_TOKEN in your project as per instructions in the documentation"
        The status should eq 1
      End
    End
  End
End
