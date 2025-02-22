# shellcheck shell=sh

# Set up common test environment
setup_test_env() {
  # Core environment variables
  export TF_VAR_environment="test"
  export TF_VAR_level="level0"
  export tf_command=""
  export TF_VAR_tfstate_subscription_id="sub123"
  export location="eastus"
  export TF_VAR_workspace="default"
  export TF_DATA_DIR="/tmp/test"
  
  # Azure authentication
  export ARM_CLIENT_ID="test-client"
  export ARM_CLIENT_SECRET="test-secret"
  export ARM_SUBSCRIPTION_ID="sub123"
  export ARM_TENANT_ID="tenant123"
  export TF_VAR_tenant_id="tenant123"
  
  # Resource naming
  export TF_VAR_tfstate_container_name="tfstate"
  export TF_VAR_tfstate_key="test.tfstate"
  export TF_VAR_logged_user_objectId="user123"
  export TF_VAR_landingzone_name="test-launchpad"
  export TF_VAR_random_length="5"
  export TF_VAR_prefix="test"
}

# Clean up test environment
cleanup_test_env() {
  unset TF_VAR_environment
  unset TF_VAR_level
  unset tf_command
  unset TF_VAR_tfstate_subscription_id
  unset location
  unset TF_VAR_workspace
  unset TF_DATA_DIR
  unset ARM_CLIENT_ID
  unset ARM_CLIENT_SECRET
  unset ARM_SUBSCRIPTION_ID
  unset ARM_TENANT_ID
  unset TF_VAR_tenant_id
  unset TF_VAR_tfstate_container_name
  unset TF_VAR_tfstate_key
  unset TF_VAR_logged_user_objectId
  unset TF_VAR_landingzone_name
  unset TF_VAR_random_length
  unset TF_VAR_prefix
}
