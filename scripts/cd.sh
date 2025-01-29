#!/bin/bash

function cd_usage {
  local code=$1
  _helpText="
  Usage:
    rover deploy <action> <flags>

  actions:
    Select one of the following options:
      * run     Terraform plan, Terraform apply, run integration tests
      * plan    Terraform plan only
      * apply   Terraform plan, Terraform apply
      * test    run integration tests

  flags:
    -env    <env name>  optional      name of the environment (defaults to sandpit)
    -level  <level>     optional      Specifiy a level only performs cd on that level. If ommitted, action is performed on all levels.
    -h | --help         optional      Show the help usage guide (this.)
"
  information "$_helpText" 1>&2

  if [ -z "$code" ]; then
    escape 0
  else
    escape $code
  fi
}

function escape {
  exit $1
}
function verify_cd_parameters {
  echo "@Verifying cd parameters"
  # Handle 1st level sub commands
  case "${cd_action}" in
    run | plan | apply )
      information "Found valid cd action - terraform ${cd_action}"
    ;;
    test)
      information "Found valid cd action ${cd_action}"
    ;;
    -h | --help)
      cd_usage
    ;;
    *)
      if [ ! -z "$cd_action" ]; then
        error_message "Invalid cd action ${cd_action}"
      fi
      cd_usage "1"
  esac

  # Handle 2nd level sub commands. Only -h|--help is supported for now
  case "${PARAMS}" in
    "-h "| "--help ")
      cd_usage
    ;;
  esac

  # verify environment
  if [ -z "$TF_VAR_environment" ]; then
    export TF_VAR_environment="sandpit"
  fi
}


function join_path {
  local base_path=$1
  local part=$2

  if [[ "$base_path" != *'/' ]]; then
     base_path="$base_path/"
  fi

  if [[ "$part" == '/'* ]]; then
     part="${part:1}"
  fi

  echo "$base_path$part"
}

# Convert AZURE_ENVIRONMENT to comply with autorest's expectations
# https://github.com/Azure/go-autorest/blob/master/autorest/azure/environments.go#L37
# To see az cli cloud names - az cloud list -o table
# We are only handling AzureCloud because the other cloud names are the same, only AzureCloud is different between az cli and autorest.
# Note the names below are camel case, Autorest converts all to upper case - https://github.com/Azure/go-autorest/blob/master/autorest/azure/environments.go#L263
function set_autorest_environment_variables {
  case $AZURE_ENVIRONMENT in
    AzureCloud)
    export AZURE_ENVIRONMENT='AzurePublicCloud'
    ;;
    AzureUSGovernment)
    export AZURE_ENVIRONMENT='AzureUSGovernmentCloud'
    ;;
  esac
}

function execute_cd {
    local action=$cd_action
    echo "@Starting CD execution"
    echo "@CD action: $action"

    local successMessage=""
    if [ "${TF_VAR_level}" == "all" ]; then
      # Default levels when no specific level is provided
      local -a levels=("level0" "level1" "level2" "level3" "level4")
    else
      # run CD for a single level
      local -a levels=($(echo $TF_VAR_level))
    fi

    for level in "${levels[@]}"
    do
        if [ "$level" == "level0" ]; then
          export caf_command="launchpad"
        else
          export caf_command="landingzone"
        fi

        information "Deploying level: $level caf_command: $caf_command"

        # Default to single stack per level
        local stack="default"
        PARAMS=""

        information "deploying stack $stack"

        # Use standard paths based on level
        landing_zone_path="landingzones/${level}"
        config_path="configuration/${level}"
        state_file_name="${level}.tfstate"
        integration_test_absolute_path="base_dir/integration_test_path"

          local plan_file="${state_file_name%.*}.tfplan"

          export landingzone_name=$landing_zone_path
          export TF_VAR_tf_name=${state_file_name}
          export TF_VAR_tf_plan=${plan_file}
          export TF_VAR_level=${level}
          expand_tfvars_folder "$config_path"
          tf_command=$(echo $PARAMS | sed -e 's/^[ \t]*//')


          log_debug @"Starting Deployment"
          log_debug "                landingzone_name: $landingzone_name"
          log_debug "                  TF_VAR_tf_name: $TF_VAR_tf_name"
          log_debug "                  TF_VAR_tf_plan: $TF_VAR_tf_plan"
          log_debug "                    TF_VAR_level: $TF_VAR_level"
          log_debug "                      tf_command: $tf_command"
          log_debug "                TF_VAR_workspace: $TF_VAR_workspace"
          log_debug "  integration_test_absolute_path: $integration_test_absolute_path"

         case "${action}" in
              run)
                  export tf_action="apply"
                  log_debug "                       tf_action: $tf_action"
                  __set_tf_log__ "rover.deploy.run"
                  deploy "${TF_VAR_workspace}"
                  __reset_log__
                  set_autorest_environment_variables
                  run_integration_tests "$integration_test_absolute_path"
                  ;;
              plan)
                  export tf_action="plan"
                  log_debug "                       tf_action: $tf_action"
                  __set_tf_log__ "rover.deploy.plan"
                  deploy "${TF_VAR_workspace}"
                  __reset_log__
                  ;;
              apply)
                  export tf_action="apply"
                  log_debug "                       tf_action: $tf_action"
                  __set_tf_log__ "rover.deploy.apply"
                  deploy "${TF_VAR_workspace}"
                  __reset_log__
                  ;;
              test)
                  set_autorest_environment_variables
                  run_integration_tests "$integration_test_absolute_path"
                  ;;
              *)
                  error "invalid cd action: $action"
          esac

          if [ ! -z "$text_log_status" ]; then
            information "$text_log_status"
          fi
    done
    success "Continuous Deployment complete."
}

