pub mod cloud;
pub mod commands;
pub mod state;

use crate::config::Config;
use anyhow::Result;

pub struct TerraformManager {
    config: Config,
}

impl TerraformManager {
    pub fn new(config: &Config) -> Result<Self> {
        Ok(Self {
            config: config.clone(),
        })
    }

    pub async fn configure_state(&self) -> Result<()> {
        match self.config.backend_type.as_str() {
            "azurerm" => state::configure_azurerm_backend(&self.config).await,
            "remote" => state::configure_remote_backend(&self.config).await,
            _ => {
                anyhow::bail!("Unsupported backend type: {}", self.config.backend_type);
            }
        }
    }

    pub async fn init(&self, landingzone_path: &str) -> Result<()> {
        commands::terraform_init(&self.config, landingzone_path).await
    }

    pub async fn plan(
        &self,
        landingzone_path: &str,
        plan_file: &Option<String>,
        var_files: &[String],
        var_folder: &Option<String>,
        parallelism: Option<u32>,
        compact_warnings: bool,
    ) -> Result<()> {
        commands::terraform_plan(
            &self.config,
            landingzone_path,
            plan_file,
            var_files,
            var_folder,
            parallelism,
            compact_warnings,
        )
        .await
    }

    pub async fn apply(&self, landingzone_path: &str, plan_file: &Option<String>) -> Result<()> {
        commands::terraform_apply(&self.config, landingzone_path, plan_file).await
    }

    pub async fn destroy(
        &self,
        landingzone_path: &str,
        var_files: &[String],
        var_folder: &Option<String>,
        parallelism: Option<u32>,
    ) -> Result<()> {
        commands::terraform_destroy(
            &self.config,
            landingzone_path,
            var_files,
            var_folder,
            parallelism,
        )
        .await
    }

    pub async fn validate(&self, landingzone_path: &str) -> Result<()> {
        commands::terraform_validate(&self.config, landingzone_path).await
    }

    pub async fn refresh(
        &self,
        landingzone_path: &str,
        var_files: &[String],
        var_folder: &Option<String>,
    ) -> Result<()> {
        commands::terraform_refresh(&self.config, landingzone_path, var_files, var_folder).await
    }

    pub async fn graph(&self, landingzone_path: &str) -> Result<()> {
        commands::terraform_graph(&self.config, landingzone_path).await
    }

    pub async fn output(&self, landingzone_path: &str) -> Result<()> {
        commands::terraform_output(&self.config, landingzone_path).await
    }

    pub async fn show(&self, landingzone_path: &str, plan_file: &Option<String>) -> Result<()> {
        commands::terraform_show(&self.config, landingzone_path, plan_file).await
    }

    pub async fn migrate(&self, landingzone_path: &str) -> Result<()> {
        commands::terraform_migrate(&self.config, landingzone_path).await
    }
}
