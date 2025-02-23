Describe 'github.com.sh'
  Include spec/support/spec_helper.sh
  Include spec/unit/lib/github.com.sh
  Include spec/unit/lib/logger.sh
  Include spec/unit/lib/functions.sh

  setup() {
    setup_test_env
    export script_path="$PWD"
    export LOG_TO_FILE="false"
    export LOG_LEVEL="INFO"
    
    # Create mock bin directory
    mkdir -p /tmp/mock_bin
    export PATH="/tmp/mock_bin:$PATH"
    
    # Create mock gh command
    cat > /tmp/mock_bin/gh << 'EOF'
#!/bin/bash
case "$1" in
  "auth")
    case "$2" in
      "status")
        echo "Logged in to github.com as testuser"
        return 0
        ;;
    esac
    ;;
  "api")
    if [[ "$2" == "repos/owner/repo" ]]; then
      echo '{"id": 12345, "svn_url": "https://github.com/owner/repo"}'
      return 0
    fi
    if [[ "$2" == "repos/owner/repo/actions/secrets" ]]; then
      echo '{"total_count": 1, "secrets": [{"name": "BOOTSTRAP_TOKEN", "created_at": "2024-02-23"}]}'
      return 0
    fi
    ;;
  "secret")
    case "$2" in
      "list")
        if [ "$3" = "-a" ] && [ "$4" = "actions" ]; then
          echo "BOOTSTRAP_TOKEN Updated 2024-02-23"
          return 0
        fi
        ;;
    esac
    ;;
esac
return 0
EOF
    chmod +x /tmp/mock_bin/gh
  }
  cleanup() {
    cleanup_test_env
    rm -rf /tmp/mock_bin
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
          "api")
            if [[ "$2" == "repos/owner/repo" ]]; then
              echo '{"id": 12345, "svn_url": "https://github.com/owner/repo"}'
              return 0
            fi
            if [[ "$2" == "repos/owner/repo/actions/secrets" ]]; then
              if [ "${mock_secret_error}" = "true" ]; then
                echo "Error: Resource not accessible by integration" >&2
                return 1
              fi
              echo '{"total_count": 1, "secrets": [{"name": "BOOTSTRAP_TOKEN", "created_at": "2024-02-23"}]}'
              return 0
            fi
            ;;
          "secret")
            case "$2" in
              "list")
                if [ "$3" = "-a" ] && [ "$4" = "actions" ]; then
                  if [ "${mock_secret_error}" = "true" ]; then
                    echo "Error: Secret not found" >&2
                    return 1
                  fi
                  echo "BOOTSTRAP_TOKEN Updated 2024-02-23"
                  return 0
                fi
                ;;
            esac
            ;;
        esac
        return 0
      }
      export -f gh
      
      # Mock git commands
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
      
      # Set up test environment
      export git_org_project="owner/repo"
      export GITHUB_TOKEN="dummy_token"
      export mock_secret_error="false"
    }

    BeforeEach 'setup'

    Context "Authentication verification"
      It 'should verify GitHub authentication successfully'
        export git_org_project="owner/repo"
        export mock_secret_error="false"
        export GITHUB_TOKEN="dummy_token"
        
        # Mock git commands for this specific test
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
        
        # Mock verify_github_secret function
        verify_github_secret() {
          return 0
        }
        export -f verify_github_secret
        When call check_github_session
        The output should include "Connected to GiHub: repos/owner/repo"
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
