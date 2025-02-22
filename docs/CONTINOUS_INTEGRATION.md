# Continuous Integration

Rover ci invokes a set of predefined tools to ensure code quality. These tools are defined via yaml files in [scripts/ci_tasks](../scripts/ci_tasks)

### Pre-requisites to running CI:

* Landing zones and configs are cloned to a base directory (eg. /tf/caf)
* Configuration follows standard Terraform workspace structure

### Run CI
* Run all CI tools

  ```shell
  rover ci -b /tf/caf -env demo -d
  ```

* Run a single ci tool by name (tflint in this example)

  ```shell
  rover ci -ct tflint -b /tf/caf -env demo -d
  ```
