package terraform

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// TerraformError represents an error that occurred during a Terraform operation
type TerraformError struct {
	Op      string // Operation that failed (plan, apply, etc)
	Path    string // Working directory or file path
	Version string // Terraform version
	Err     error  // Underlying error
}

func (e *TerraformError) Error() string {
	if e.Version != "" {
		return fmt.Sprintf("terraform %s failed (version %s) at %s: %v", e.Op, e.Version, e.Path, e.Err)
	}
	return fmt.Sprintf("terraform %s failed at %s: %v", e.Op, e.Path, e.Err)
}

func (e *TerraformError) Unwrap() error {
	return e.Err
}

// VersionError represents an error related to Terraform version compatibility
type VersionError struct {
	Current  string
	Required string
	Feature  string
}

func (e *VersionError) Error() string {
	return fmt.Sprintf("terraform version %s does not support %s (requires %s)", e.Current, e.Feature, e.Required)
}

// Backend represents the configuration for either azurerm or remote backend
type Backend struct {
	Type            string // "azurerm" or "remote"
	StorageAccount  string // azurerm only
	ResourceGroup   string // azurerm only
	ContainerName   string // azurerm only
	Key             string // azurerm only
	SubscriptionID  string // azurerm only
	Organization    string // remote only
	Hostname        string // remote only
	WorkspaceName   string // remote only
}

type Operations struct {
	WorkingDir     string
	DataDir        string
	Level          string
	Workspace      string
	StateName      string
	PlanName       string
	NoColor        bool
	Version        string
	Command        string
	backend        Backend
	envVars       map[string]string
}

var requiredEnvVars = []string{
	"TF_VAR_workspace",
	"TF_DATA_DIR",
	"TF_VAR_level",
	"TF_VAR_tf_name",
	"TF_VAR_tf_plan",
	"TF_VAR_environment",
	"TF_VAR_tfstate_subscription_id",
	"TF_VAR_tfstate_storage_account_name",
	"TF_VAR_tfstate_resource_group_name",
	"TF_VAR_tf_cloud_organization",
	"TF_VAR_tf_cloud_hostname",
}

func NewOperations(workingDir, dataDir, level, workspace string, backend Backend) (*Operations, error) {
	stateName := filepath.Base(workingDir) + ".tfstate"
	planName := filepath.Base(workingDir) + ".tfplan"

	envVars := make(map[string]string)
	for _, key := range requiredEnvVars {
		if value := os.Getenv(key); value != "" {
			envVars[key] = value
		}
	}

	version := os.Getenv("TF_VERSION")
	if version == "" {
		version = "1.0.0"
	}

	return &Operations{
		WorkingDir: workingDir,
		DataDir:    dataDir,
		Level:      level,
		Workspace:  workspace,
		StateName:  stateName,
		PlanName:   planName,
		Version:    version,
		backend:    backend,
		envVars:    envVars,
	}, nil
}

func (o *Operations) getStatePath() string {
	return filepath.Join(o.DataDir, "tfstates", o.Level, o.Workspace, o.StateName)
}

func (o *Operations) getPlanPath() string {
	return filepath.Join(o.DataDir, "tfstates", o.Level, o.Workspace, o.PlanName)
}

func (o *Operations) Init(ctx context.Context) error {
	if err := o.setEnvVars(); err != nil {
		return &TerraformError{Op: "init", Path: o.WorkingDir, Version: o.Version, Err: err}
	}

	if err := o.cleanup(); err != nil {
		return &TerraformError{Op: "init", Path: o.WorkingDir, Version: o.Version, Err: fmt.Errorf("cleanup failed: %v", err)}
	}

	if err := os.MkdirAll(filepath.Dir(o.getStatePath()), 0755); err != nil {
		return &TerraformError{Op: "init", Path: o.getStatePath(), Version: o.Version, Err: fmt.Errorf("failed to create state directory: %v", err)}
	}

	// Create backend config based on type and version
	if o.isVersion015OrGreater() {
		switch o.backend.Type {
		case "azurerm":
			return o.initAzureRM015(ctx)
		case "remote":
			return o.initRemote015(ctx)
		default:
			return fmt.Errorf("unsupported backend type: %s", o.backend.Type)
		}
	}

	switch o.backend.Type {
	case "azurerm":
		return o.initAzureRM(ctx)
	case "remote":
		return o.initRemote(ctx)
	default:
		return fmt.Errorf("unsupported backend type: %s", o.backend.Type)
	}
}

func (o *Operations) initAzureRM(ctx context.Context) error {
	backendConfig := fmt.Sprintf(`terraform {
    backend "azurerm" {
        storage_account_name = "%s"
        resource_group_name = "%s"
        container_name = "%s"
        key = "%s"
        subscription_id = "%s"
    }
}`, o.backend.StorageAccount, o.backend.ResourceGroup, o.backend.ContainerName, o.backend.Key, o.backend.SubscriptionID)

	backendPath := filepath.Join(o.WorkingDir, "backend.azurerm.tf")
	if err := os.WriteFile(backendPath, []byte(backendConfig), 0644); err != nil {
		return &TerraformError{Op: "init", Path: backendPath, Version: o.Version,
			Err: fmt.Errorf("failed to write azurerm backend config: %v", err)}
	}
	return nil
}

func (o *Operations) initAzureRM015(ctx context.Context) error {
	backendConfig := fmt.Sprintf(`terraform {
    backend "azurerm" {}
}`)
	backendPath := filepath.Join(o.WorkingDir, "backend.azurerm.tf")
	if err := os.WriteFile(backendPath, []byte(backendConfig), 0644); err != nil {
		return &TerraformError{Op: "init", Path: backendPath, Version: o.Version,
			Err: fmt.Errorf("failed to write azurerm backend config: %v", err)}
	}

	hclConfig := fmt.Sprintf(`storage_account_name = "%s"
resource_group_name = "%s"
container_name = "%s"
key = "%s"
subscription_id = "%s"`, o.backend.StorageAccount, o.backend.ResourceGroup, o.backend.ContainerName, o.backend.Key, o.backend.SubscriptionID)

	hclPath := filepath.Join(o.WorkingDir, "backend.hcl")
	if err := os.WriteFile(hclPath, []byte(hclConfig), 0644); err != nil {
		return &TerraformError{Op: "init", Path: hclPath, Version: o.Version,
			Err: fmt.Errorf("failed to write backend hcl config: %v", err)}
	}
	return nil
}

func (o *Operations) initRemote(ctx context.Context) error {
	backendConfig := fmt.Sprintf(`terraform {
    backend "remote" {
        workspaces { name = "%s" }
        hostname = "%s"
        organization = "%s"
    }
}`, o.backend.WorkspaceName, o.backend.Hostname, o.backend.Organization)

	backendPath := filepath.Join(o.WorkingDir, "backend.hcl.tf")
	if err := os.WriteFile(backendPath, []byte(backendConfig), 0644); err != nil {
		return &TerraformError{Op: "init", Path: backendPath, Version: o.Version,
			Err: fmt.Errorf("failed to write remote backend config: %v", err)}
	}
	return nil
}

func (o *Operations) initRemote015(ctx context.Context) error {
	backendConfig := fmt.Sprintf(`terraform {
    backend "remote" {}
}`)
	backendPath := filepath.Join(o.WorkingDir, "backend.hcl.tf")
	if err := os.WriteFile(backendPath, []byte(backendConfig), 0644); err != nil {
		return &TerraformError{Op: "init", Path: backendPath, Version: o.Version,
			Err: fmt.Errorf("failed to write remote backend config: %v", err)}
	}

	hclConfig := fmt.Sprintf(`workspaces { name = "%s" }
hostname = "%s"
organization = "%s"`, o.backend.WorkspaceName, o.backend.Hostname, o.backend.Organization)

	hclPath := filepath.Join(o.WorkingDir, "backend.hcl")
	if err := os.WriteFile(hclPath, []byte(hclConfig), 0644); err != nil {
		return &TerraformError{Op: "init", Path: hclPath, Version: o.Version,
			Err: fmt.Errorf("failed to write backend hcl config: %v", err)}
	}
	return nil
}

func (o *Operations) Plan(ctx context.Context, destroy bool) error {
	if err := os.MkdirAll(filepath.Dir(o.getStatePath()), 0755); err != nil {
		return &TerraformError{Op: "plan", Path: o.getStatePath(), Version: o.Version, 
			Err: fmt.Errorf("failed to create state directory: %v", err)}
	}

	if err := o.setEnvVars(); err != nil {
		return &TerraformError{Op: "plan", Path: o.WorkingDir, Version: o.Version, Err: err}
	}

	planCmd := o.Command
	if destroy {
		planCmd = "-destroy " + planCmd
	}

	statePath := o.getStatePath()
	planPath := o.getPlanPath()

	if err := os.MkdirAll(filepath.Dir(planPath), 0755); err != nil {
		return &TerraformError{Op: "plan", Path: planPath, Version: o.Version,
			Err: fmt.Errorf("failed to create plan directory: %v", err)}
	}

	if o.isVersion015OrGreater() {
		return &TerraformError{Op: "plan", Path: o.WorkingDir, Version: o.Version,
			Err: &VersionError{Current: o.Version, Required: "0.15+", Feature: "new state management"}}
	}
	return &TerraformError{Op: "plan", Path: o.WorkingDir, Version: o.Version,
		Err: fmt.Errorf("waiting for terraform-exec package")}
}

func (o *Operations) Apply(ctx context.Context) error {
	if err := o.setEnvVars(); err != nil {
		return &TerraformError{Op: "apply", Path: o.WorkingDir, Version: o.Version, Err: err}
	}

	planPath := o.getPlanPath()
	if _, err := os.Stat(planPath); os.IsNotExist(err) {
		return &TerraformError{Op: "apply", Path: planPath, Version: o.Version,
			Err: fmt.Errorf("plan file not found")}
	}

	if o.isVersion015OrGreater() {
		return &TerraformError{Op: "apply", Path: o.WorkingDir, Version: o.Version,
			Err: &VersionError{Current: o.Version, Required: "0.15+", Feature: "state locking"}}
	}
	return &TerraformError{Op: "apply", Path: o.WorkingDir, Version: o.Version,
		Err: fmt.Errorf("waiting for terraform-exec package")}
}

func (o *Operations) Destroy(ctx context.Context) error {
	if err := o.setEnvVars(); err != nil {
		return &TerraformError{Op: "destroy", Path: o.WorkingDir, Version: o.Version, Err: err}
	}

	if err := o.Plan(ctx, true); err != nil {
		return &TerraformError{Op: "destroy", Path: o.WorkingDir, Version: o.Version,
			Err: fmt.Errorf("failed to create destroy plan: %v", err)}
	}

	if o.isVersion015OrGreater() {
		return &TerraformError{Op: "destroy", Path: o.WorkingDir, Version: o.Version,
			Err: &VersionError{Current: o.Version, Required: "0.15+", Feature: "state locking"}}
	}
	return &TerraformError{Op: "destroy", Path: o.WorkingDir, Version: o.Version,
		Err: fmt.Errorf("waiting for terraform-exec package")}
}

func (o *Operations) Show(ctx context.Context) error {
	if err := o.setEnvVars(); err != nil {
		return &TerraformError{Op: "show", Path: o.WorkingDir, Version: o.Version, Err: err}
	}

	statePath := o.getStatePath()
	if _, err := os.Stat(statePath); os.IsNotExist(err) {
		return &TerraformError{Op: "show", Path: statePath, Version: o.Version,
			Err: fmt.Errorf("state file not found")}
	}

	if o.isVersion015OrGreater() {
		return &TerraformError{Op: "show", Path: o.WorkingDir, Version: o.Version,
			Err: &VersionError{Current: o.Version, Required: "0.15+", Feature: "state output format"}}
	}
	return &TerraformError{Op: "show", Path: o.WorkingDir, Version: o.Version,
		Err: fmt.Errorf("waiting for terraform-exec package")}
}

func (o *Operations) Validate(ctx context.Context) error {
	if err := o.setEnvVars(); err != nil {
		return &TerraformError{Op: "validate", Path: o.WorkingDir, Version: o.Version, Err: err}
	}

	if o.isVersion015OrGreater() {
		return &TerraformError{Op: "validate", Path: o.WorkingDir, Version: o.Version,
			Err: &VersionError{Current: o.Version, Required: "0.15+", Feature: "validation rules"}}
	}
	return &TerraformError{Op: "validate", Path: o.WorkingDir, Version: o.Version,
		Err: fmt.Errorf("waiting for terraform-exec package")}
}

func (o *Operations) isVersion015OrGreater() bool {
	return strings.HasPrefix(o.Version, "15") || strings.HasPrefix(o.Version, "1.")
}

func (o *Operations) getEnvVar(key string) string {
	if val, ok := o.envVars[key]; ok {
		return val
	}
	return os.Getenv(key)
}

func (o *Operations) setEnvVars() error {
	for key, value := range o.envVars {
		if err := os.Setenv(key, value); err != nil {
			return fmt.Errorf("error setting environment variable %s: %v", key, err)
		}
	}
	return nil
}

func (o *Operations) cleanup() error {
	patterns := []string{
		filepath.Join(o.WorkingDir, "backend.*.tf"),
		filepath.Join(o.WorkingDir, "backend.hcl"),
		filepath.Join(o.WorkingDir, "caf.auto.tfvars"),
		filepath.Join(o.DataDir, "terraform.tfstate"),
		filepath.Join(o.DataDir, "tfstates", o.Level, o.Workspace, "*.tfstate"),
		filepath.Join(o.DataDir, "tfstates", o.Level, o.Workspace, "*.tfplan"),
	}

	var errs []string
	for _, pattern := range patterns {
		matches, err := filepath.Glob(pattern)
		if err != nil {
			errs = append(errs, fmt.Sprintf("failed to glob pattern %s: %v", pattern, err))
			continue
		}
		for _, match := range matches {
			if err := os.Remove(match); err != nil && !os.IsNotExist(err) {
				errs = append(errs, fmt.Sprintf("failed to remove %s: %v", match, err))
			}
		}
	}

	if len(errs) > 0 {
		return &TerraformError{
			Op:      "cleanup",
			Path:    o.WorkingDir,
			Version: o.Version,
			Err:     fmt.Errorf("cleanup errors:\n%s", strings.Join(errs, "\n")),
		}
	}
	return nil
}
