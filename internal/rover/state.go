package rover

import (
	"context"
	"fmt"
	"path/filepath"

	"github.com/arnaudlh/rover/internal/azure"
	"github.com/arnaudlh/rover/internal/terraform"
)

type StateManager struct {
	storage    *azure.StorageClient
	terraform  *terraform.Operations
	level      string
	workspace  string
	stateName  string
	dataDir    string
	workingDir string
}

func NewStateManager(ctx context.Context, subscriptionID, level, workspace, workingDir, dataDir string) (*StateManager, error) {
	storage, err := azure.NewStorageClient(subscriptionID)
	if err != nil {
		return nil, fmt.Errorf("failed to create storage client: %v", err)
	}

	stateName := filepath.Base(workingDir) + ".tfstate"

	// Configure backend based on environment variables
	backend := terraform.Backend{
		Type:           "azurerm",
		StorageAccount: getEnvVar("TF_VAR_tfstate_storage_account_name", ""),
		ResourceGroup:  getEnvVar("TF_VAR_tfstate_resource_group_name", ""),
		ContainerName:  workspace,
		Key:           stateName,
		SubscriptionID: subscriptionID,
	}

	tfOps, err := terraform.NewOperations(workingDir, dataDir, level, workspace, backend)
	if err != nil {
		return nil, fmt.Errorf("failed to create terraform operations: %v", err)
	}

	return &StateManager{
		storage:    storage,
		terraform:  tfOps,
		level:      level,
		workspace:  workspace,
		stateName:  stateName,
		dataDir:    dataDir,
		workingDir: workingDir,
	}, nil
}

func (m *StateManager) InitializeState(ctx context.Context) error {
	if err := m.terraform.Init(ctx); err != nil {
		return fmt.Errorf("failed to initialize terraform: %v", err)
	}
	return nil
}

func (m *StateManager) UploadState(ctx context.Context) error {
	statePath := filepath.Join(m.dataDir, "tfstates", m.level, m.workspace, m.stateName)
	data, err := os.ReadFile(statePath)
	if err != nil {
		return fmt.Errorf("failed to read state file: %v", err)
	}

	filter := azure.StorageAccountFilter{
		Level:       m.level,
		Environment: getEnvVar("TF_VAR_environment", ""),
	}

	account, err := m.storage.GetStorageAccountByFilter(ctx, filter)
	if err != nil {
		return fmt.Errorf("failed to get storage account: %v", err)
	}

	if err := m.storage.UploadTFState(ctx, *account.ResourceGroup, *account.Name, m.workspace, m.stateName, data); err != nil {
		return fmt.Errorf("failed to upload state: %v", err)
	}
	return nil
}

func (m *StateManager) DownloadState(ctx context.Context) error {
	filter := azure.StorageAccountFilter{
		Level:       m.level,
		Environment: getEnvVar("TF_VAR_environment", ""),
	}

	account, err := m.storage.GetStorageAccountByFilter(ctx, filter)
	if err != nil {
		return fmt.Errorf("failed to get storage account: %v", err)
	}

	data, err := m.storage.DownloadTFState(ctx, *account.ResourceGroup, *account.Name, m.workspace, m.stateName)
	if err != nil {
		return fmt.Errorf("failed to download state: %v", err)
	}

	statePath := filepath.Join(m.dataDir, "tfstates", m.level, m.workspace, m.stateName)
	if err := os.MkdirAll(filepath.Dir(statePath), 0755); err != nil {
		return fmt.Errorf("failed to create state directory: %v", err)
	}

	if err := os.WriteFile(statePath, data, 0644); err != nil {
		return fmt.Errorf("failed to write state file: %v", err)
	}
	return nil
}

func (m *StateManager) Plan(ctx context.Context, destroy bool) error {
	if err := m.DownloadState(ctx); err != nil {
		return fmt.Errorf("failed to download state: %v", err)
	}

	if err := m.terraform.Plan(ctx, destroy); err != nil {
		return fmt.Errorf("failed to create plan: %v", err)
	}
	return nil
}

func (m *StateManager) Apply(ctx context.Context) error {
	if err := m.DownloadState(ctx); err != nil {
		return fmt.Errorf("failed to download state: %v", err)
	}

	if err := m.terraform.Apply(ctx); err != nil {
		return fmt.Errorf("failed to apply changes: %v", err)
	}

	if err := m.UploadState(ctx); err != nil {
		return fmt.Errorf("failed to upload state: %v", err)
	}
	return nil
}

func (m *StateManager) Destroy(ctx context.Context) error {
	if err := m.DownloadState(ctx); err != nil {
		return fmt.Errorf("failed to download state: %v", err)
	}

	if err := m.terraform.Destroy(ctx); err != nil {
		return fmt.Errorf("failed to destroy resources: %v", err)
	}

	if err := m.UploadState(ctx); err != nil {
		return fmt.Errorf("failed to upload state: %v", err)
	}
	return nil
}

func (m *StateManager) Show(ctx context.Context) error {
	if err := m.DownloadState(ctx); err != nil {
		return fmt.Errorf("failed to download state: %v", err)
	}

	if err := m.terraform.Show(ctx); err != nil {
		return fmt.Errorf("failed to show state: %v", err)
	}
	return nil
}

func (m *StateManager) Validate(ctx context.Context) error {
	if err := m.terraform.Validate(ctx); err != nil {
		return fmt.Errorf("failed to validate configuration: %v", err)
	}
	return nil
}

func getEnvVar(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
