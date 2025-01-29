Describe 'logger.sh'
  Include scripts/functions.sh
  Include scripts/lib/logger.sh
  
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
      setup() {
        unset log_folder_path
      }
      BeforeEach 'setup'

      It 'should use default log path'
        When call __log_init__
        The variable log_folder_path should eq "$HOME/.rover/logs"
        The status should eq 0
      End
    End

    Context "Log Path is Set"
      setup() {
        export log_folder_path="tmp/$(uuidgen)"
      }
      BeforeEach 'setup'

      It 'should use the specified log path'
        When call __log_init__
        The variable log_folder_path should eq "$log_folder_path"
        The status should eq 0
      End
    End

  End
End
