use anyhow::Result;
use crate::{auth::azure::AzureAuth, config::Config};

pub async fn execute(
    config: &Config,
    tenant: &Option<String>,
    subscription: &Option<String>,
) -> Result<()> {
    tracing::info!("Logging into Azure");

    let azure_auth = AzureAuth::new(config)?;
    
    azure_auth.login(tenant.as_deref(), subscription.as_deref()).await?;
    
    tracing::info!("Azure login completed");
    Ok(())
}
