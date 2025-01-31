package azure

import (
	"context"
	"errors"
	"fmt"
	"io"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/storage/armstorage"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
)

type StorageClient struct {
	SubscriptionID string
	credential    *azidentity.DefaultAzureCredential
	storageClient *armstorage.AccountsClient
}

type StorageAccountFilter struct {
	Level       string
	Environment string
}

func (f *StorageAccountFilter) matches(tags map[string]*string) bool {
	if tags == nil {
		return false
	}

	// Check both old and new tag formats
	tfstateTag := tags["caf_tfstate"]
	if tfstateTag == nil {
		tfstateTag = tags["tfstate"]
	}
	if tfstateTag == nil || *tfstateTag != f.Level {
		return false
	}

	envTag := tags["caf_environment"]
	if envTag == nil {
		envTag = tags["environment"]
	}
	if envTag == nil || *envTag != f.Environment {
		return false
	}

	return true
}

func NewStorageClient(subscriptionID string) (*StorageClient, error) {
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create credential: %v", err)
	}

	client, err := armstorage.NewAccountsClient(subscriptionID, cred, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create storage client: %v", err)
	}

	return &StorageClient{
		SubscriptionID: subscriptionID,
		credential:    cred,
		storageClient: client,
	}, nil
}

func (c *StorageClient) GetStorageAccountByFilter(ctx context.Context, filter StorageAccountFilter) (*armstorage.Account, error) {
	pager := c.storageClient.NewListPager(nil)
	
	for pager.More() {
		page, err := pager.NextPage(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to list storage accounts: %v", err)
		}
		
		for _, account := range page.Value {
			if filter.matches(account.Tags) {
				return account, nil
			}
		}
	}
	
	return nil, fmt.Errorf("no storage account found matching level '%s' and environment '%s'", filter.Level, filter.Environment)
}

func (c *StorageClient) GetStorageAccountKeys(ctx context.Context, resourceGroup, accountName string) ([]armstorage.AccountKey, error) {
	resp, err := c.storageClient.ListKeys(ctx, resourceGroup, accountName, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to list storage account keys: %v", err)
	}
	return *resp.Keys, nil
}

func (c *StorageClient) UploadTFState(ctx context.Context, resourceGroup, accountName, containerName, blobName string, data []byte) error {
	keys, err := c.GetStorageAccountKeys(ctx, resourceGroup, accountName)
	if err != nil {
		return fmt.Errorf("failed to get storage account keys: %v", err)
	}
	if len(keys) == 0 {
		return fmt.Errorf("no storage account keys found")
	}

	cred, err := azblob.NewSharedKeyCredential(accountName, *keys[0].Value)
	if err != nil {
		return fmt.Errorf("failed to create shared key credential: %v", err)
	}

	serviceClient, err := azblob.NewClientWithSharedKeyCredential(
		fmt.Sprintf("https://%s.blob.core.windows.net/", accountName),
		cred,
		nil,
	)
	if err != nil {
		return fmt.Errorf("failed to create blob client: %v", err)
	}

	_, err = serviceClient.UploadBuffer(ctx, containerName, blobName, data, nil)
	if err != nil {
		return fmt.Errorf("failed to upload state file: %v", err)
	}

	return nil
}

func (c *StorageClient) getBlobClient(ctx context.Context, resourceGroup, accountName string) (*azblob.Client, error) {
	keys, err := c.GetStorageAccountKeys(ctx, resourceGroup, accountName)
	if err != nil {
		return nil, fmt.Errorf("failed to get storage account keys: %v", err)
	}
	if len(keys) == 0 {
		return nil, fmt.Errorf("no storage account keys found")
	}

	cred, err := azblob.NewSharedKeyCredential(accountName, *keys[0].Value)
	if err != nil {
		return nil, fmt.Errorf("failed to create shared key credential: %v", err)
	}

	return azblob.NewClientWithSharedKeyCredential(
		fmt.Sprintf("https://%s.blob.core.windows.net/", accountName),
		cred,
		nil,
	)
}

func (c *StorageClient) BlobExists(ctx context.Context, resourceGroup, accountName, containerName, blobName string) (bool, error) {
	client, err := c.getBlobClient(ctx, resourceGroup, accountName)
	if err != nil {
		return false, err
	}

	_, err = client.GetBlobClient(containerName, blobName).GetProperties(ctx, nil)
	if err != nil {
		var storageErr *azblob.ResponseError
		if errors.As(err, &storageErr) && storageErr.ErrorCode == "BlobNotFound" {
			return false, nil
		}
		return false, fmt.Errorf("failed to check blob existence: %v", err)
	}
	return true, nil
}

func (c *StorageClient) DownloadTFState(ctx context.Context, resourceGroup, accountName, containerName, blobName string) ([]byte, error) {
	client, err := c.getBlobClient(ctx, resourceGroup, accountName)
	if err != nil {
		return nil, err
	}

	exists, err := c.BlobExists(ctx, resourceGroup, accountName, containerName, blobName)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, fmt.Errorf("state file does not exist: %s", blobName)
	}

	download, err := client.DownloadStream(ctx, containerName, blobName, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to download state file: %v", err)
	}

	data, err := io.ReadAll(download.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read state file: %v", err)
	}

	return data, nil
}

func (c *StorageClient) DeleteTFState(ctx context.Context, resourceGroup, accountName, containerName, blobName string) error {
	client, err := c.getBlobClient(ctx, resourceGroup, accountName)
	if err != nil {
		return err
	}

	exists, err := c.BlobExists(ctx, resourceGroup, accountName, containerName, blobName)
	if err != nil {
		return err
	}
	if !exists {
		return nil // Already deleted
	}

	_, err = client.GetBlobClient(containerName, blobName).Delete(ctx, &azblob.DeleteBlobOptions{
		DeleteSnapshots: true,
	})
	if err != nil {
		return fmt.Errorf("failed to delete state file: %v", err)
	}

	return nil
}
