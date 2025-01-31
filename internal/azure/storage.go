package azure

import (
	"context"
	"fmt"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/storage/armstorage"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
)

type StorageClient struct {
	SubscriptionID string
	credential    *azidentity.DefaultAzureCredential
	storageClient *armstorage.AccountsClient
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

func (c *StorageClient) ListStorageAccounts(ctx context.Context) ([]*armstorage.Account, error) {
	pager := c.storageClient.NewListPager(nil)
	var accounts []*armstorage.Account

	for pager.More() {
		page, err := pager.NextPage(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to list storage accounts: %v", err)
		}
		accounts = append(accounts, page.Value...)
	}
	return accounts, nil
}

func (c *StorageClient) UploadTFState(ctx context.Context, accountName, containerName, blobName string, data []byte) error {
	serviceClient, err := azblob.NewClient(fmt.Sprintf("https://%s.blob.core.windows.net/", accountName), c.credential, nil)
	if err != nil {
		return fmt.Errorf("failed to create blob client: %v", err)
	}

	_, err = serviceClient.UploadBuffer(ctx, containerName, blobName, data, nil)
	if err != nil {
		return fmt.Errorf("failed to upload state file: %v", err)
	}

	return nil
}

func (c *StorageClient) DownloadTFState(ctx context.Context, accountName, containerName, blobName string) ([]byte, error) {
	serviceClient, err := azblob.NewClient(fmt.Sprintf("https://%s.blob.core.windows.net/", accountName), c.credential, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create blob client: %v", err)
	}

	download, err := serviceClient.DownloadStream(ctx, containerName, blobName, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to download state file: %v", err)
	}

	data, err := download.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("failed to read state file: %v", err)
	}

	return data, nil
}

func (c *StorageClient) DeleteTFState(ctx context.Context, accountName, containerName, blobName string) error {
	serviceClient, err := azblob.NewClient(fmt.Sprintf("https://%s.blob.core.windows.net/", accountName), c.credential, nil)
	if err != nil {
		return fmt.Errorf("failed to create blob client: %v", err)
	}

	_, err = serviceClient.DeleteBlob(ctx, containerName, blobName, nil)
	if err != nil {
		return fmt.Errorf("failed to delete state file: %v", err)
	}

	return nil
}
