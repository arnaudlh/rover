Describe 'terraform.sh'
  Include spec_helper.sh
  Include ./terraform.sh
  Include ./logger.sh
  Include ./functions.sh

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
          "init")
            echo "Terraform has been successfully initialized!"
            return 0
            ;;
          "plan")
            echo "Plan: 1 to add, 0 to change, 0 to destroy."
            return 0
            ;;
          "version")
            echo "Terraform v1.5.7"
            return 0
            ;;
        esac
        return 0
      }
    }

    BeforeEach 'setup'

    It 'should generate plan successfully'
      When call terraform_plan
      The output should include "Terraform has been successfully initialized!"
      The output should include "Plan: 1 to add, 0 to change, 0 to destroy."
      The status should eq 0
    End

    It 'should handle terraform init failure'
      terraform() { return 1; }
      When call terraform_plan
      The status should eq 1
    End
  End

  Describe "terraform_apply"
    setup() {
      # Mock functions
      terraform() {
        case "$1" in
          "apply")
            echo "Apply complete! Resources: 1 added, 0 changed, 0 destroyed."
            return 0
            ;;
        esac
        return 0
      }
    }

    BeforeEach 'setup'

    It 'should apply changes successfully'
      When call terraform_apply
      The output should include "Apply complete!"
      The status should eq 0
    End

    It 'should handle terraform apply failure'
      terraform() { return 1; }
      When call terraform_apply
      The status should eq 1
    End
  End
End
