package azure

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/storage/armstorage"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"

)

type readSeekCloser struct {
	*bytes.Reader
}

func (r *readSeekCloser) Close() error {
	return nil
}

func newReadSeekCloser(data []byte) *readSeekCloser {
	return &readSeekCloser{bytes.NewReader(data)}
}

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
	keys := make([]armstorage.AccountKey, len(resp.Keys))
	for i, key := range resp.Keys {
		keys[i] = *key
	}
	return keys, nil
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

	containerClient := serviceClient.ServiceClient().NewContainerClient(containerName)
	blobClient := containerClient.NewBlockBlobClient(blobName)
	reader := newReadSeekCloser(data)
	_, err = blobClient.Upload(ctx, reader, nil)
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

	containerClient := client.ServiceClient().NewContainerClient(containerName)
	blobClient := containerClient.NewBlockBlobClient(blobName)
	_, err = blobClient.GetProperties(ctx, nil)
	if err != nil {
		if err != nil && err.Error() == "The specified blob does not exist." {
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

	containerClient := client.ServiceClient().NewContainerClient(containerName)
	blobClient := containerClient.NewBlockBlobClient(blobName)
	resp, err := blobClient.DownloadStream(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to download state file: %v", err)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read state file: %v", err)
	}
	defer resp.Body.Close()

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

	containerClient := client.ServiceClient().NewContainerClient(containerName)
	blobClient := containerClient.NewBlockBlobClient(blobName)
	_, err = blobClient.Delete(ctx, &azblob.DeleteBlobOptions{
		DeleteSnapshots: toPtr(azblob.DeleteSnapshotsOptionType("include")),
	})
	if err != nil {
		return fmt.Errorf("failed to delete state file: %v", err)
	}

	return nil
}

func toPtr[T any](v T) *T {
	return &v
}
