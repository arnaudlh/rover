Describe 'logger.sh'
  # Mock tfcloud script sourcing from functions.sh
  export script_path="$(pwd)/scripts"
  mkdir -p "${script_path}/tfcloud"
  touch "${script_path}/tfcloud/mock.sh"
  
  Include scripts/functions.sh
  Include scripts/lib/logger.sh
  
  # Mock functions
  tfstate_cleanup() { :; }
  
  Describe "__log_init__"
    #Function Mocks
    export TEST_DEBUG_CREATE_DIR=true
    error() {
        local parent_lineno="$1"
        local message="$2"
        local code="$3"
        >&2 echo "Error line:${parent_lineno}: message:${message} status :${code}"
        export TEST_DEBUG_CREATE_DIR=false
        return ${code}
    }
    __create_dir__ (){
      if [ "$TEST_DEBUG_CREATE_DIR" == "true" ]; then
        echo "creating directory $1"
      fi
    }

    Context "Log Path Not Set"
      It 'should throw an error and not create directory'
        When call __log_init__
        The error should include 'Error line:0: message:Log folder path is not set status :1'  
      End
    End

    Context "Log Path is Set"
      setup() {
        export log_folder_path="tmp/$(uuidgen)"
      }
      BeforeEach 'setup'

      It 'should throw an error and not create directory'
        unset log_folder_path
        When call __log_init__
        The stderr should eq "Error line:0: message:Log folder path is not set status :1\n"
        The status should eq 1
        The stdout should eq ""
        The output should eq ""
      End
    End
  End

  Describe 'log level management'
    Context "when setting log levels"
      setup() {
        export log_folder_path="tmp/$(uuidgen)"
        __log_init__
      }
      BeforeEach 'setup'

      It 'should set default level to INFO'
        When call set_log_severity "INFO"
        The variable "_loggers_level_map[default]" should eq "3"
      End

      It 'should handle invalid log levels'
        When call set_log_severity "INVALID"
        The error should include "Unknown log level"
        The variable "_loggers_level_map[default]" should eq "3"
      End
    End

    Context "when logging at different levels"
      setup() {
        export log_folder_path="tmp/$(uuidgen)"
        __log_init__
      }
      BeforeEach 'setup'

      Example "should respect INFO log level"
        When call set_log_severity "INFO"
        The variable "_loggers_level_map[default]" should eq "3"
      End

      Example "should respect VERBOSE log level"
        When call set_log_severity "VERBOSE"
        The variable "_loggers_level_map[default]" should eq "5"
        The status should eq 0
      End
    End
  End

  Describe 'file logging'
    Context "when setting up log files"
      setup() {
        export log_folder_path="tmp/$(uuidgen)"
        __log_init__
      }
      BeforeEach 'setup'

      It 'should create log directory'
        When call __set_text_log__ "test"
        The path "$log_folder_path" should be directory
      End

      It 'should create log file with correct name'
        When call __set_text_log__ "test"
        The path "$CURRENT_LOG_FILE" should be file
        The output should include "Detailed Logs @"
        The output should include "STARTING LOG OUTPUT TO"
      End

      It 'should handle reset correctly'
        __set_text_log__ "test"
        When call __reset_log__
        The variable "LOG_TO_FILE" should eq "false"
        The variable "CURRENT_LOG_FILE" should be undefined
        The output should include "STOPPING LOG OUTPUT TO"
      End
    End
  End

  Describe 'output formatting'
    Context "when logging messages"
      setup() {
        export log_folder_path="tmp/$(uuidgen)"
        __log_init__
      }
      BeforeEach 'setup'

      It 'should format error messages with correct color'
        When call error_message "test error"
        The stderr should include $'\e[91m'
        The stderr should include $'\e[0m'
      End

      It 'should format warning messages with correct color'
        When call warning "test warning"
        The output should include $'\e[33m'
        The output should include $'\e[0m'
      End

      It 'should format success messages with correct color'
        When call success "test success"
        The output should include $'\e[32m'
        The output should include $'\e[0m'
      End

      It 'should include timestamp and level in log messages'
        When call log_info "test message"
        The stderr should eq ""
        The output should match pattern "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} UTC \[INFO\] \[/home/runner/\.local/lib/shellspec/lib/core/evaluation\.sh:[0-9]+\] test message"
        The status should eq 0
        The status should eq 0
      End

      It 'should include source file and line information'
        When call log_info "test message"
        The output should include ".sh:"
      End
    End
  End
End
