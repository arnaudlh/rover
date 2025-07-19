use anyhow::Result;
use crate::{auth::azure::AzureAuth, config::Config};

pub async fn execute(config: &Config) -> Result<()> {
    tracing::info!("Logging out of Azure");

    let azure_auth = AzureAuth::new(config)?;
    
    azure_auth.logout().await?;
    
    tracing::info!("Azure logout completed");
    Ok(())
}
