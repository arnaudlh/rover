Describe 'terraform.sh'
  Include spec/support/spec_helper.sh
  Include spec/unit/lib/terraform.sh
  Include spec/unit/lib/logger.sh
  Include spec/unit/lib/functions.sh

  setup() {
    setup_test_env
    mkdir -p "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
    export script_path="$PWD"
  }
  cleanup() {
    cleanup_test_env
    rm -rf "${TF_DATA_DIR}/tfstates"
  }
  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe "terraform_plan"
    setup() {
      # Mock functions
      terraform() {
        case "$1" in
          "-chdir=${landingzone_name}")
            case "$2" in
              "plan")
                echo "Plan: 1 to add, 0 to change, 0 to destroy."
                return 0
                ;;
            esac
            ;;
          "plan")
            echo "Plan: 1 to add, 0 to change, 0 to destroy."
            return 0
            ;;
          "version")
            echo "Terraform ${terraform_version}"
            return 0
            ;;
        esac
        return 0
      }
      export landingzone_name="test-landingzone"
      export TF_DATA_DIR="/tmp/test"
      export TF_VAR_level="level0"
      export TF_VAR_workspace="default"
      export TF_VAR_tf_name="test.tfstate"
      export TF_VAR_tf_plan="test.tfplan"
      export tf_output_file="/tmp/tf_output.log"
    }

    BeforeEach 'setup'

    Context "Terraform version handling"
      It 'should use -chdir with Terraform 1.x'
        export terraform_version="v1.5.7"
        When call terraform_plan
        The output should include "@calling plan"
        The output should include "Running Terraform plan..."
        The output should include "Plan: 1 to add, 0 to change, 0 to destroy."
        The status should eq 0
      End

      It 'should use legacy syntax with Terraform 0.x'
        export terraform_version="v0.14.7"
        When call terraform_plan
        The output should include "@calling plan"
        The output should include "Running Terraform plan..."
        The output should include "Plan: 1 to add, 0 to change, 0 to destroy."
        The status should eq 0
      End
    End

    Context "Error handling"
      It 'should handle terraform plan failure'
        terraform() { return 1; }
        When call terraform_plan
        The status should eq 1
      End

      It 'should handle non-empty diff'
        terraform() { return 2; }
        When call terraform_plan
        The output should include "terraform plan succeeded with non-empty diff"
        The status should eq 0
      End
    End
  End

  Describe "terraform_apply"
    setup() {
      # Mock functions
      terraform() {
        case "$1" in
          "-chdir=${landingzone_name}")
            case "$2" in
              "apply")
                echo "Apply complete! Resources: 1 added, 0 changed, 0 destroyed."
                return 0
                ;;
            esac
            ;;
          "apply")
            echo "Apply complete! Resources: 1 added, 0 changed, 0 destroyed."
            return 0
            ;;
        esac
        return 0
      }
      export landingzone_name="test-landingzone"
      export TF_DATA_DIR="/tmp/test"
      export TF_VAR_level="level0"
      export TF_VAR_workspace="default"
      export TF_VAR_tf_name="test.tfstate"
      export TF_VAR_tf_plan="test.tfplan"
      export tf_output_file="/tmp/tf_output.log"
      export gitops_terraform_backend_type="azurerm"
    }

    BeforeEach 'setup'

    Context "Backend type handling"
      It 'should handle azurerm backend with plan'
        export tf_plan_file="/tmp/test/tfstates/level0/default/test.tfplan"
        When call terraform_apply
        The output should include "@calling terraform_apply"
        The output should include "running terraform apply - azurerm"
        The output should include "Apply complete!"
        The status should eq 0
      End

      It 'should handle remote backend without plan'
        export gitops_terraform_backend_type="remote"
        When call terraform_apply
        The output should include "@calling terraform_apply"
        The output should include "running terraform apply - remote"
        The output should include "Apply complete!"
        The status should eq 0
      End
    End

    Context "Error handling"
      It 'should handle terraform apply failure'
        terraform() { return 1; }
        When call terraform_apply
        The status should eq 1
        The stderr should include "Error running terraform apply"
      End
    End
  End
End
