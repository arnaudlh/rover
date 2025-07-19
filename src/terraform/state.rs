use crate::config::Config;
use anyhow::{Context, Result};
use std::fs;

pub async fn configure_azurerm_backend(config: &Config) -> Result<()> {
    tracing::info!("Configuring AzureRM backend");

    let tf_data_dir = config.get_tf_data_dir();
    let workspace = config.get_workspace();
    let level = config.get_level();

    let state_dir = tf_data_dir.join("tfstates").join(&level).join(&workspace);
    fs::create_dir_all(&state_dir).context("Failed to create state directory")?;

    tracing::info!(
        "AzureRM backend configured with state directory: {:?}",
        state_dir
    );
    Ok(())
}

pub async fn configure_remote_backend(config: &Config) -> Result<()> {
    tracing::info!("Configuring Terraform Cloud backend");

    if config.tf_cloud_hostname.is_none() || config.tf_cloud_organization.is_none() {
        anyhow::bail!("Terraform Cloud hostname and organization must be set for remote backend");
    }

    tracing::info!("Remote backend configured for Terraform Cloud");
    Ok(())
}

pub async fn cleanup_state(config: &Config) -> Result<()> {
    tracing::info!("Cleaning up Terraform state");

    let tf_data_dir = config.get_tf_data_dir();
    let workspace = config.get_workspace();
    let level = config.get_level();

    let state_dir = tf_data_dir.join("tfstates").join(&level).join(&workspace);

    if state_dir.exists() {
        fs::remove_dir_all(&state_dir).context("Failed to remove state directory")?;
        tracing::info!("State directory cleaned: {:?}", state_dir);
    }

    Ok(())
}
