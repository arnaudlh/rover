#!/usr/bin/env bash

# Continual logging methods. These always print regardless of log level
error_message() {
    printf >&2 "\e[91m$@\n\e[0m"
}

information() {
    printf "\e[36m$@\n\e[0m"
}

warning() {
    printf "\e[33m$@\n\e[0m"
}

success() {
    printf "\e[32m$@\n\e[0m"
}

# legacy shim
debug() {
    local message=$1
    log_debug $message
}

__log_init__() {

    # Set Time zone to UTC / Comment out to use local time
    export TZ=UTC

    # map log level strings (FATAL, ERROR, etc.) to numeric values
    # Note the '-g' option passed to declare - it is essential

    unset _log_levels _loggers_level_map
    declare -gA _log_levels _loggers_level_map
    _log_levels=([FATAL]=0 [ERROR]=1 [WARN]=2 [INFO]=3 [DEBUG]=4 [VERBOSE]=5)


    # hash to map loggers to their log levels
    # the default logger "default" has INFO as its default log level
    _loggers_level_map["default"]=3  # the log level for the default logger is INFO

    #------------------------------------------------------------------------------
    # make sure log directory exists in standard log folder
    #------------------------------------------------------------------------------

    if [ -z "$log_folder_path" ]; then
        TEST_DEBUG_CREATE_DIR=false
        printf "Error line:0: message:Log folder path is not set status :1\n" >&2
        return 1
    fi

    if [ ! -d "$log_folder_path" ]; then
        printf "creating directory %s\n" "$log_folder_path"
        __create_dir__ "$log_folder_path"
    fi

}

__create_dir__()  {
    local path=$1
    mkdir -p $path
}

__set_tf_log__() {
    local name=$1
    local logDate=$(date +%Y.%m.%d)

    if [ ! -d "$log_folder_path/$logDate" ]; then
      mkdir -p "$log_folder_path/$logDate"
    fi

    export TF_LOG_PATH="$log_folder_path/$logDate/tf_raw_$name.log"
    __set_text_log__ "$name"
}


get_log_folder(){
  local logDate=$(date +%Y.%m.%d)
  local current_log_folder="$log_folder_path/$logDate"
  if [ ! -d "$current_log_folder" ]; then
    mkdir -p "$current_log_folder"
  fi
  echo $current_log_folder
}

__set_text_log__() {
    local name=$1
    local logDate=$(date +%Y.%m.%d)

    if [ ! -d "$log_folder_path/$logDate" ]; then
      mkdir -p "$log_folder_path/$logDate"
    fi

    CURRENT_LOG_FILE="$log_folder_path/$logDate/$name.log"
    export CURRENT_LOG_FILE
    information "Detailed Logs @ $CURRENT_LOG_FILE"
    exec 3>&1 4>&2
    echo "------------------------------------------------------------------------------------------------------"
    printf "STARTING LOG OUTPUT TO : %s\n" "$CURRENT_LOG_FILE"
    echo "------------------------------------------------------------------------------------------------------"
    LOG_TO_FILE=true
    export LOG_TO_FILE
    exec 1>> "$CURRENT_LOG_FILE" 2>&1
}

__reset_log__() {
    local current_log="$CURRENT_LOG_FILE"
    echo "------------------------------------------------------------------------------------------------------"
    printf "STOPPING LOG OUTPUT TO : %s\n" "$current_log"
    echo "------------------------------------------------------------------------------------------------------"
    LOG_TO_FILE=false
    export LOG_TO_FILE
    exec 2>&4 1>&3
    [ -f "$current_log" ] && sed -i 's/\x1b\[[0-9;]*m//g' "$current_log"
    unset CURRENT_LOG_FILE TF_LOG_PATH
}

#------------------------------------------------------------------------------
# export_tf_environment_variables
#
# ROVER             TF            AUTOMATION
# ------------------------------------------
# VERBOSE          TRACE          OFF
# DEBUG            DEBUG          ON
# INFO             INFO           ON
# WARN             WARN           ON
# ERROR            ERROR          ON
# FATAL            ERROR          ON
#
#------------------------------------------------------------------------------
export_tf_environment_variables() {
  local severity=$1
  export LOG_SEVERITY=$severity

  local tfLog
  local isAutomation=false
  case $severity in
    VERBOSE)
      tfLog="TRACE"
      isAutomation=false
      ;;
    DEBUG)
      tfLog="DEBUG"
      isAutomation=true
      ;;
    INFO)
      tfLog="INFO"
      isAutomation=true
      ;;
    WARN)
      tfLog="WARN"
      isAutomation=true
      ;;
    ERROR)
      tfLog="ERROR"
      isAutomation=true
      ;;
    FATAL)
      tfLog="ERROR"
      isAutomation=true
      ;;
    *)
      printf >&2 "Error scripts/lib/logger.sh on or near line 0: Unknown log level; exiting with status 1\n"
      return 1
      ;;
  esac

  export TF_LOG_PROVIDER=$tfLog

  if [ "$isAutomation" == "true" ]; then
    export TF_IN_AUTOMATION="true"
  else
    unset TF_IN_AUTOMATION
  fi
}

#------------------------------------------------------------------------------
# set_log_severity
#------------------------------------------------------------------------------
set_log_severity() {
    local logger=default in_level l
    export_tf_environment_variables "$1"

    [[ $1 = "-l" ]] && { logger=$2; shift 2 2>/dev/null; }
    in_level="${1:-INFO}"

    if [[ $logger ]]; then
        l="${_log_levels[$in_level]}"

        if [[ $l ]]; then
            _loggers_level_map[$logger]=$l

        else
            printf '%(%Y-%m-%dT%H:%M:%S)T UTC' -1
            printf ' [%s] [%s] ' "WARN" "${BASH_SOURCE[2]}:${BASH_LINENO[1]}"
            printf 'Unknown log level %s for logger %s; setting to INFO\n' "$in_level" "$logger"
            _loggers_level_map[$logger]=3
        fi
    else
        printf '%(%Y-%m-%dT%H:%M:%S)T UTC' -1
        printf ' [%s] [%s] ' "WARN" "${BASH_SOURCE[2]}:${BASH_LINENO[1]}"
        printf 'Option -l needs an argument\n' >&2
    fi
}


_log() {
    local in_level=$1; shift
    local logger=default log_level_set log_level
   # [[ $1 = "-l" ]] && { logger=$2; shift 2; }

    log_level="${_log_levels[$in_level]}"
    log_level_set="${_loggers_level_map[$logger]}"

    if [[ $log_level_set ]]; then
         if [ "$log_level_set" -ge "$log_level" ]; then
            printf '%(%Y-%m-%dT%H:%M:%S)T UTC [%s] [%s] %s\n' -1 "$in_level" "${BASH_SOURCE[2]}:${BASH_LINENO[1]}" "$*"
         fi
     else
         printf '%(%Y-%m-%dT%H:%M:%S)T UTC [%s] [%s] Unknown logger %s\n' -1 "WARN" "${BASH_SOURCE[2]}:${BASH_LINENO[1]}" "$logger"
    fi
}


#------------------------------------------------------------------------------
# main logging functions
#------------------------------------------------------------------------------
log_fatal()   { _log FATAL   "$@"; }
log_error()   { _log ERROR   "$@"; }
log_warn()    { _log WARN    "$@"; }
log_info()    { _log INFO    "$@"; }
log_debug()   { _log DEBUG   "$@"; }
log_verbose() { _log VERBOSE "$@"; }
log_if_exists() {
  local raw=$1
  local formatted=$2
   if [ ! -z "$raw" ]; then
    echo $formatted
  fi
}

#------------------------------------------------------------------------------
# logging for function entry and exit
#------------------------------------------------------------------------------
log_info_enter()    { _log INFO    "Entering function ${FUNCNAME[1]}"; }
log_debug_enter()   { _log DEBUG   "Entering function ${FUNCNAME[1]}"; }
log_verbose_enter() { _log VERBOSE "Entering function ${FUNCNAME[1]}"; }
log_info_leave()    { _log INFO    "Leaving function ${FUNCNAME[1]}";  }
log_debug_leave()   { _log DEBUG   "Leaving function ${FUNCNAME[1]}";  }
log_verbose_leave() { _log VERBOSE "Leaving function ${FUNCNAME[1]}";  }

