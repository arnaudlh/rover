package rover

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/storage/armstorage"
	"github.com/arnaudlh/rover/internal/azure"
	"github.com/arnaudlh/rover/internal/terraform"
)

type StorageClient interface {
	GetStorageAccountByFilter(ctx context.Context, filter azure.StorageAccountFilter) (*armstorage.Account, error)
	UploadTFState(ctx context.Context, resourceGroup, accountName, containerName, blobName string, data []byte) error
	DownloadTFState(ctx context.Context, resourceGroup, accountName, containerName, blobName string) ([]byte, error)
}

type TerraformOperations interface {
	Init(context.Context) error
	Plan(context.Context, bool) error
	Apply(context.Context) error
	Destroy(context.Context) error
	Show(context.Context) error
	Validate(context.Context) error
}

type StateManager struct {
	storage    StorageClient
	terraform  TerraformOperations
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

	resourceGroup, err := getResourceGroup(account)
	if err != nil {
		return fmt.Errorf("failed to get resource group: %v", err)
	}
	if err := m.storage.UploadTFState(ctx, resourceGroup, *account.Name, m.workspace, m.stateName, data); err != nil {
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

	resourceGroup, err := getResourceGroup(account)
	if err != nil {
		return fmt.Errorf("failed to get resource group: %v", err)
	}
	data, err := m.storage.DownloadTFState(ctx, resourceGroup, *account.Name, m.workspace, m.stateName)
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

func getResourceGroupFromID(id string) (string, error) {
	parts := strings.Split(id, "/")
	for i := 0; i < len(parts)-1; i++ {
		if parts[i] == "resourceGroups" {
			return parts[i+1], nil
		}
	}
	return "", fmt.Errorf("resource group not found in ID: %s", id)
}

func getResourceGroup(account *armstorage.Account) (string, error) {
	if account.ID == nil {
		return "", fmt.Errorf("account ID is nil")
	}
	return getResourceGroupFromID(*account.ID)
}
