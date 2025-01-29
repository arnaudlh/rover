#!/bin/bash

source "${script_path}/lib/task.sh"

declare -a CI_TASK_CONFIG_FILE_LIST=()
declare -a REGISTERED_CI_TASKS=()
declare CI_TASK_DIR=${script_path}/ci_tasks

function verify_task_name(){
    local ci_task_name=$1
    local isTaskNameRegistered=$(task_is_registered "$ci_task_name")
    if [ "$isTaskNameRegistered" != "true" ]; then
        export code="1"
        error "1" "$ci_task_name is not a registered ci command!"
        return $code
    fi
}

function verify_ci_parameters {
    echo "@Verifying ci parameters"

    # Verify environment
    if [ -z "$TF_VAR_environment" ]; then
        export TF_VAR_environment="sandpit"
    fi

    # verify ci task name is valid
    if [ ! -z "$ci_task_name" ]; then
        verify_task_name "$ci_task_name"
    fi
}

function set_default_parameters {
    echo "@Setting default parameters"
    export caf_command="landingzone"

    # export landingzone_name=<landing_zone_path>
    # export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename ${landingzone_name}).tfstate"}

    # export tf_action=<action name plan|apply|validate>
    # expand_tfvars_folder <var folder path>
    # deploy ${TF_VAR_workspace}
}

function register_ci_tasks {
  echo @"Registering available ci task..."

  # Get List of config files
  CI_TASK_CONFIG_FILE_LIST=$(get_list_of_task ${CI_TASK_DIR})

  # For each config, grab the tool name
  # TODO: Eventually we will want to validate configs.  For now, we can assume if the yaml parses it is valid.
  for config in $CI_TASK_CONFIG_FILE_LIST
  do
    task_name=$(get_task_name ${config})
    echo @"Registered task... '${task_name}'"
    REGISTERED_CI_TASKS+=("${task_name}")
  done

}

function task_is_registered {
  local task_name=$1
  for task in "${REGISTERED_CI_TASKS[@]}"
  do
    if [ "$task" == "$task_name" ]; then
      echo "true"
      return
    fi
  done
  echo "false"
}

function execute_ci_actions {
    echo "@Starting CI tools execution"

    if [ "${TF_VAR_level}" == "all" ]; then
      # Default levels when no specific level is provided
      local -a levels=("level0" "level1" "level2" "level3" "level4")
      # echo "get all levels"
    else
      # run CI for a single level
      if [[ ! "${TF_VAR_level}" =~ ^level[0-4]$ ]]; then
        error ${LINENO} "Invalid level specified"
        return 1
      fi
      local -a levels=($(echo $TF_VAR_level))
      # echo "single level CI - ${TF_VAR_level}"
    fi

    for level in "${levels[@]}"
    do
        # Default to single stack per level
        local stack="default"
        landing_zone_path="landingzones/${level}"
        config_path="configuration/${level}"

          if [ ! -z "$ci_task_name" ]; then
            # run a single task by name
            run_task "$ci_task_name" "$level" "$landing_zone_path" "$config_path"
          else
            # run all tasks
            for task in "${REGISTERED_CI_TASKS[@]}"
            do
              run_task "$task" "$level" "$landing_zone_path" "$config_path"
            done
            echo " "
          fi
    done

    success "All CI tasks have run successfully."
}

function clone_repos {
  echo @"Cloning repo ${1}"
  # TODO: We will start with git clone prior to CI execution.
}
