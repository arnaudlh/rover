use clap::Parser;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

use crate::commands::Commands;

#[derive(Parser, Debug, Clone)]
#[command(name = "rover")]
#[command(about = "🚀 Terraform wrapper for Azure state management and CI/CD integration")]
#[command(version)]
pub struct Config {
    #[command(subcommand)]
    pub command: Option<Commands>,

    #[arg(short, long, env = "TF_VAR_level")]
    pub level: Option<String>,

    #[arg(short, long, env = "TF_VAR_workspace")]
    pub workspace: Option<String>,

    #[arg(long, env = "TF_VAR_tf_name")]
    pub tf_name: Option<String>,

    #[arg(long, env = "TF_VAR_tf_plan")]
    pub tf_plan: Option<String>,

    #[arg(long, env = "landingzone_name")]
    pub landingzone_name: Option<PathBuf>,

    #[arg(long, env = "TF_DATA_DIR")]
    pub tf_data_dir: Option<PathBuf>,

    #[arg(long, env = "TF_CACHE_FOLDER")]
    pub tf_cache_folder: Option<PathBuf>,

    #[arg(long, env = "ARM_SUBSCRIPTION_ID")]
    pub subscription_id: Option<String>,

    #[arg(long, env = "ARM_TENANT_ID")]
    pub tenant_id: Option<String>,

    #[arg(long, env = "ARM_CLIENT_ID")]
    pub client_id: Option<String>,

    #[arg(long, env = "ARM_CLIENT_SECRET")]
    pub client_secret: Option<String>,

    #[arg(long, env = "ARM_USE_OIDC")]
    pub use_oidc: Option<bool>,

    #[arg(long, env = "TF_VAR_tf_cloud_hostname")]
    pub tf_cloud_hostname: Option<String>,

    #[arg(long, env = "TF_VAR_tf_cloud_organization")]
    pub tf_cloud_organization: Option<String>,

    #[arg(long, env = "gitops_terraform_backend_type", default_value = "azurerm")]
    pub backend_type: String,

    #[arg(long, env = "backend_type_hybrid")]
    pub backend_type_hybrid: Option<bool>,

    #[arg(long, env = "target_subscription")]
    pub target_subscription: Option<String>,

    #[arg(long, env = "sp_keyvault_url")]
    pub sp_keyvault_url: Option<String>,

    #[arg(long, env = "tenant")]
    pub tenant: Option<String>,

    #[arg(long, env = "subscription")]
    pub subscription: Option<String>,

    #[arg(long, env = "LOG_SEVERITY", default_value = "INFO")]
    pub log_severity: String,

    #[arg(long, env = "log_folder_path")]
    pub log_folder_path: Option<PathBuf>,

    #[arg(long)]
    pub tf_no_color: bool,

    #[arg(long)]
    pub devops: bool,

    #[arg(long)]
    pub debug: bool,
}

impl Config {
    pub fn get_tf_data_dir(&self) -> PathBuf {
        self.tf_data_dir.clone().unwrap_or_else(|| {
            dirs::cache_dir()
                .unwrap_or_else(|| PathBuf::from("/tmp"))
                .join("terraform")
        })
    }

    pub fn get_tf_cache_folder(&self) -> PathBuf {
        self.tf_cache_folder.clone().unwrap_or_else(|| {
            dirs::cache_dir()
                .unwrap_or_else(|| PathBuf::from("/tmp"))
                .join("terraform_cache")
        })
    }

    pub fn get_log_folder_path(&self) -> PathBuf {
        self.log_folder_path.clone().unwrap_or_else(|| {
            dirs::cache_dir()
                .unwrap_or_else(|| PathBuf::from("/tmp"))
                .join("rover_logs")
        })
    }

    pub fn get_workspace(&self) -> String {
        self.workspace
            .clone()
            .unwrap_or_else(|| "default".to_string())
    }

    pub fn get_level(&self) -> String {
        self.level.clone().unwrap_or_else(|| "level0".to_string())
    }

    pub fn get_tf_name(&self) -> String {
        self.tf_name
            .clone()
            .unwrap_or_else(|| "terraform.tfstate".to_string())
    }

    pub fn get_tf_plan(&self) -> String {
        self.tf_plan
            .clone()
            .unwrap_or_else(|| "terraform.tfplan".to_string())
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TerraformConfig {
    pub backend_type: String,
    pub workspace: String,
    pub level: String,
    pub tf_name: String,
    pub tf_plan: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AzureConfig {
    pub subscription_id: Option<String>,
    pub tenant_id: Option<String>,
    pub client_id: Option<String>,
    pub client_secret: Option<String>,
    pub use_oidc: bool,
}
