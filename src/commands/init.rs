use anyhow::Result;
use crate::{config::Config, terraform::TerraformManager};

#[allow(clippy::too_many_arguments)]
pub async fn execute(
    config: &Config,
    landingzone_path: &str,
    plan: bool,
    apply: bool,
    destroy: bool,
    validate: bool,
    refresh: bool,
    graph: bool,
    _import: bool,
    output: bool,
    _taint: bool,
    _untaint: bool,
    _state_list: bool,
    _state_rm: bool,
    _state_show: bool,
    show: bool,
    migrate: bool,
    plan_file: &Option<String>,
    var_file: &[String],
    var_folder: &Option<String>,
    parallelism: Option<u32>,
    compact_warnings: bool,
    _launchpad: bool,
) -> Result<()> {
    tracing::info!("Initializing Terraform configuration at: {}", landingzone_path);

    let terraform = TerraformManager::new(config)?;
    
    terraform.configure_state().await?;
    
    terraform.init(landingzone_path).await?;

    if plan {
        terraform.plan(landingzone_path, plan_file, var_file, var_folder, parallelism, compact_warnings).await?;
    }

    if apply {
        terraform.apply(landingzone_path, plan_file).await?;
    }

    if destroy {
        terraform.destroy(landingzone_path, var_file, var_folder, parallelism).await?;
    }

    if validate {
        terraform.validate(landingzone_path).await?;
    }

    if refresh {
        terraform.refresh(landingzone_path, var_file, var_folder).await?;
    }

    if graph {
        terraform.graph(landingzone_path).await?;
    }

    if output {
        terraform.output(landingzone_path).await?;
    }

    if show {
        terraform.show(landingzone_path, plan_file).await?;
    }

    if migrate {
        terraform.migrate(landingzone_path).await?;
    }

    Ok(())
}
