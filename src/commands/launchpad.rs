use crate::{config::Config, terraform::TerraformManager};
use anyhow::Result;

pub async fn execute(
    config: &Config,
    landingzone_path: &str,
    plan: bool,
    apply: bool,
    destroy: bool,
) -> Result<()> {
    tracing::info!("Managing launchpad at: {}", landingzone_path);

    let terraform = TerraformManager::new(config)?;

    terraform.configure_state().await?;

    terraform.init(landingzone_path).await?;

    if plan {
        terraform
            .plan(landingzone_path, &None, &[], &None, None, false)
            .await?;
    }

    if apply {
        terraform.apply(landingzone_path, &None).await?;
    }

    if destroy {
        terraform
            .destroy(landingzone_path, &[], &None, None)
            .await?;
    }

    Ok(())
}
