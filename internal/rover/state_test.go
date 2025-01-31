package rover

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/storage/armstorage"
	"github.com/arnaudlh/rover/internal/azure"

)

type mockStorageClient struct {
	getAccountByFilterFunc func(context.Context, azure.StorageAccountFilter) (*armstorage.Account, error)
	uploadStateFunc       func(context.Context, string, string, string, string, []byte) error
	downloadStateFunc     func(context.Context, string, string, string, string) ([]byte, error)
}

func (m *mockStorageClient) GetStorageAccountByFilter(ctx context.Context, filter azure.StorageAccountFilter) (*armstorage.Account, error) {
	if m.getAccountByFilterFunc != nil {
		return m.getAccountByFilterFunc(ctx, filter)
	}
	return &armstorage.Account{
		ID:   toPtr("/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/account1"),
		Name: toPtr("account1"),
	}, nil
}

func (m *mockStorageClient) UploadTFState(ctx context.Context, resourceGroup, accountName, containerName, blobName string, data []byte) error {
	if m.uploadStateFunc != nil {
		return m.uploadStateFunc(ctx, resourceGroup, accountName, containerName, blobName, data)
	}
	return nil
}

func (m *mockStorageClient) DownloadTFState(ctx context.Context, resourceGroup, accountName, containerName, blobName string) ([]byte, error) {
	if m.downloadStateFunc != nil {
		return m.downloadStateFunc(ctx, resourceGroup, accountName, containerName, blobName)
	}
	return []byte("mock state"), nil
}

type mockTerraformOps struct {
	initFunc     func(context.Context) error
	planFunc     func(context.Context, bool) error
	applyFunc    func(context.Context) error
	destroyFunc  func(context.Context) error
	showFunc     func(context.Context) error
	validateFunc func(context.Context) error
}

func (m *mockTerraformOps) Init(ctx context.Context) error {
	if m.initFunc != nil {
		return m.initFunc(ctx)
	}
	return nil
}

func (m *mockTerraformOps) Plan(ctx context.Context, destroy bool) error {
	if m.planFunc != nil {
		return m.planFunc(ctx, destroy)
	}
	return nil
}

func (m *mockTerraformOps) Apply(ctx context.Context) error {
	if m.applyFunc != nil {
		return m.applyFunc(ctx)
	}
	return nil
}

func (m *mockTerraformOps) Destroy(ctx context.Context) error {
	if m.destroyFunc != nil {
		return m.destroyFunc(ctx)
	}
	return nil
}

func (m *mockTerraformOps) Show(ctx context.Context) error {
	if m.showFunc != nil {
		return m.showFunc(ctx)
	}
	return nil
}

func (m *mockTerraformOps) Validate(ctx context.Context) error {
	if m.validateFunc != nil {
		return m.validateFunc(ctx)
	}
	return nil
}

func TestStateManager_InitializeState(t *testing.T) {
	tests := []struct {
		name      string
		mockTf    *mockTerraformOps
		wantError bool
	}{
		{
			name: "successful init",
			mockTf: &mockTerraformOps{
				initFunc: func(ctx context.Context) error {
					return nil
				},
			},
			wantError: false,
		},
		{
			name: "init error",
			mockTf: &mockTerraformOps{
				initFunc: func(ctx context.Context) error {
					return os.ErrNotExist
				},
			},
			wantError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sm := &StateManager{
				terraform: tt.mockTf,
			}

			err := sm.InitializeState(context.Background())
			if (err != nil) != tt.wantError {
				t.Errorf("InitializeState() error = %v, wantError %v", err, tt.wantError)
			}
		})
	}
}

func TestStateManager_UploadState(t *testing.T) {
	tmpDir := t.TempDir()
	stateDir := filepath.Join(tmpDir, "tfstates", "level0", "dev")
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		t.Fatal(err)
	}
	statePath := filepath.Join(stateDir, "test.tfstate")
	if err := os.WriteFile(statePath, []byte("test state"), 0644); err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		name        string
		mockStorage *mockStorageClient
		wantError   bool
	}{
		{
			name: "successful upload",
			mockStorage: &mockStorageClient{
				uploadStateFunc: func(ctx context.Context, rg, acc, container, blob string, data []byte) error {
					return nil
				},
			},
			wantError: false,
		},
		{
			name: "upload error",
			mockStorage: &mockStorageClient{
				uploadStateFunc: func(ctx context.Context, rg, acc, container, blob string, data []byte) error {
					return os.ErrPermission
				},
			},
			wantError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sm := &StateManager{
				storage:    tt.mockStorage,
				level:     "level0",
				workspace: "dev",
				stateName: "test.tfstate",
				dataDir:   tmpDir,
			}

			err := sm.UploadState(context.Background())
			if (err != nil) != tt.wantError {
				t.Errorf("UploadState() error = %v, wantError %v", err, tt.wantError)
			}
		})
	}
}

func toPtr[T any](v T) *T {
	return &v
}
