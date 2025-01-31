package terraform

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestOperations_Init(t *testing.T) {
	tmpDir := t.TempDir()
	workingDir := filepath.Join(tmpDir, "test")
	dataDir := filepath.Join(tmpDir, "data")

	if err := os.MkdirAll(workingDir, 0755); err != nil {
		t.Fatalf("Failed to create working directory: %v", err)
	}
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		t.Fatalf("Failed to create data directory: %v", err)
	}

	tests := []struct {
		name       string
		workingDir string
		dataDir    string
		level      string
		workspace  string
		backend    Backend
		wantErr    bool
	}{
		{
			name:       "valid init",
			workingDir: workingDir,
			dataDir:    dataDir,
			level:      "level0",
			workspace:  "dev",
			backend: Backend{
				Type:           "azurerm",
				StorageAccount: "testaccount",
				ResourceGroup:  "testrg",
				ContainerName:  "dev",
				Key:           "test.tfstate",
				SubscriptionID: "00000000-0000-0000-0000-000000000000",
			},
			wantErr: false,
		},
		{
			name:       "invalid working directory",
			workingDir: "",
			wantErr:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ops, err := NewOperations(tt.workingDir, tt.dataDir, tt.level, tt.workspace, tt.backend)
			if tt.wantErr {
				if err == nil {
					t.Error("NewOperations() error = nil, wantErr true")
				}
				return
			}
			if err != nil {
				t.Errorf("NewOperations() error = %v, wantErr false", err)
				return
			}

			if err := ops.Init(context.Background()); (err != nil) != tt.wantErr {
				t.Errorf("Operations.Init() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestOperations_Plan(t *testing.T) {
	tmpDir := t.TempDir()
	workingDir := filepath.Join(tmpDir, "test")
	dataDir := filepath.Join(tmpDir, "data")

	if err := os.MkdirAll(workingDir, 0755); err != nil {
		t.Fatalf("Failed to create working directory: %v", err)
	}
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		t.Fatalf("Failed to create data directory: %v", err)
	}

	tests := []struct {
		name       string
		workingDir string
		dataDir    string
		level      string
		workspace  string
		backend    Backend
		destroy    bool
		wantErr    bool
	}{
		{
			name:       "valid plan",
			workingDir: workingDir,
			dataDir:    dataDir,
			level:      "level0",
			workspace:  "dev",
			backend: Backend{
				Type:           "azurerm",
				StorageAccount: "testaccount",
				ResourceGroup:  "testrg",
				ContainerName:  "dev",
				Key:           "test.tfstate",
				SubscriptionID: "00000000-0000-0000-0000-000000000000",
			},
			destroy:    false,
			wantErr:    true, // Expected to fail with "waiting for terraform-exec package"
		},
		{
			name:       "valid destroy plan",
			workingDir: workingDir,
			dataDir:    dataDir,
			level:      "level0",
			workspace:  "dev",
			backend: Backend{
				Type:           "azurerm",
				StorageAccount: "testaccount",
				ResourceGroup:  "testrg",
				ContainerName:  "dev",
				Key:           "test.tfstate",
				SubscriptionID: "00000000-0000-0000-0000-000000000000",
			},
			destroy:    true,
			wantErr:    true, // Expected to fail with "waiting for terraform-exec package"
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ops, err := NewOperations(tt.workingDir, tt.dataDir, tt.level, tt.workspace, tt.backend)
			if err != nil {
				t.Fatalf("NewOperations() error = %v", err)
			}
			if err := ops.Plan(context.Background(), tt.destroy); (err != nil) != tt.wantErr {
				t.Errorf("Operations.Plan() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestOperations_Apply(t *testing.T) {
	tmpDir := t.TempDir()
	workingDir := filepath.Join(tmpDir, "test")
	dataDir := filepath.Join(tmpDir, "data")

	if err := os.MkdirAll(workingDir, 0755); err != nil {
		t.Fatalf("Failed to create working directory: %v", err)
	}
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		t.Fatalf("Failed to create data directory: %v", err)
	}

	tests := []struct {
		name       string
		workingDir string
		dataDir    string
		level      string
		workspace  string
		backend    Backend
		wantErr    bool
	}{
		{
			name:       "valid apply",
			workingDir: workingDir,
			dataDir:    dataDir,
			level:      "level0",
			workspace:  "dev",
			backend: Backend{
				Type:           "azurerm",
				StorageAccount: "testaccount",
				ResourceGroup:  "testrg",
				ContainerName:  "dev",
				Key:           "test.tfstate",
				SubscriptionID: "00000000-0000-0000-0000-000000000000",
			},
			wantErr:    true, // Expected to fail with "plan file not found"
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ops, err := NewOperations(tt.workingDir, tt.dataDir, tt.level, tt.workspace, tt.backend)
			if err != nil {
				t.Fatalf("NewOperations() error = %v", err)
			}
			if err := ops.Apply(context.Background()); (err != nil) != tt.wantErr {
				t.Errorf("Operations.Apply() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
