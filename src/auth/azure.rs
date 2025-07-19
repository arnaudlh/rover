use anyhow::{Context, Result};
use serde_json::Value;
use tokio::process::Command;
use crate::config::Config;

pub struct AzureAuth {
    config: Config,
}

impl AzureAuth {
    pub fn new(config: &Config) -> Result<Self> {
        Ok(Self {
            config: config.clone(),
        })
    }

    pub async fn login(&self, tenant: Option<&str>, subscription: Option<&str>) -> Result<()> {
        tracing::info!("Checking existing Azure session");
        
        if let Ok(session) = self.get_current_session().await {
            if !session.is_null() {
                tracing::info!("Already logged in to Azure");
                return Ok(());
            }
        }

        if let Some(sp_keyvault_url) = &self.config.sp_keyvault_url {
            tracing::info!("Logging in using service principal from Key Vault");
            return self.login_as_sp_from_keyvault_secrets(sp_keyvault_url).await;
        }

        if self.has_service_principal_env_vars() {
            tracing::info!("Service principal environment variables detected");
            return self.login_with_service_principal().await;
        }

        tracing::info!("Logging in with device code flow");
        self.login_with_device_code(tenant).await?;

        if let Some(sub) = subscription {
            tracing::info!("Setting default subscription to: {}", sub);
            self.set_subscription(sub).await?;
        }

        Ok(())
    }

    pub async fn logout(&self) -> Result<()> {
        tracing::info!("Closing Azure session");
        
        let output = Command::new("az")
            .args(["logout"])
            .output()
            .await
            .context("Failed to execute az logout")?;

        if !output.status.success() {
            tracing::warn!("Azure logout may have failed: {}", String::from_utf8_lossy(&output.stderr));
        }

        Ok(())
    }

    pub async fn create_federated_identity(&self, app_name: &str) -> Result<()> {
        tracing::info!("Creating federated identity for app: {}", app_name);
        
        let apps = self.list_apps_by_name(app_name).await?;
        
        if apps.is_empty() {
            tracing::info!("Creating new Azure AD application: {}", app_name);
            self.create_app_and_sp(app_name).await?;
        } else {
            tracing::info!("Azure AD application already exists: {}", app_name);
        }

        Ok(())
    }

    async fn get_current_session(&self) -> Result<Value> {
        let output = Command::new("az")
            .args(["account", "show", "-o", "json"])
            .output()
            .await
            .context("Failed to execute az account show")?;

        if output.status.success() {
            let session: Value = serde_json::from_slice(&output.stdout)
                .context("Failed to parse Azure session JSON")?;
            Ok(session)
        } else {
            Ok(Value::Null)
        }
    }

    fn has_service_principal_env_vars(&self) -> bool {
        self.config.client_id.is_some() 
            && self.config.client_secret.is_some() 
            && self.config.subscription_id.is_some() 
            && self.config.tenant_id.is_some()
    }

    async fn login_with_service_principal(&self) -> Result<()> {
        let client_id = self.config.client_id.as_ref().unwrap();
        let client_secret = self.config.client_secret.as_ref().unwrap();
        let tenant_id = self.config.tenant_id.as_ref().unwrap();

        let output = Command::new("az")
            .args([
                "login",
                "--service-principal",
                "-u", client_id,
                "-p", client_secret,
                "-t", tenant_id,
            ])
            .output()
            .await
            .context("Failed to execute az login with service principal")?;

        if !output.status.success() {
            anyhow::bail!("Service principal login failed: {}", String::from_utf8_lossy(&output.stderr));
        }

        Ok(())
    }

    async fn login_with_device_code(&self, tenant: Option<&str>) -> Result<()> {
        let mut cmd = Command::new("az");
        cmd.args(["login", "--use-device-code"]);
        
        if let Some(t) = tenant {
            cmd.args(["--tenant", t]);
        }

        let output = cmd
            .output()
            .await
            .context("Failed to execute az login with device code")?;

        if !output.status.success() {
            anyhow::bail!("Device code login failed: {}", String::from_utf8_lossy(&output.stderr));
        }

        Ok(())
    }

    async fn set_subscription(&self, subscription: &str) -> Result<()> {
        let output = Command::new("az")
            .args(["account", "set", "-s", subscription])
            .output()
            .await
            .context("Failed to set Azure subscription")?;

        if !output.status.success() {
            anyhow::bail!("Failed to set subscription: {}", String::from_utf8_lossy(&output.stderr));
        }

        Ok(())
    }

    async fn login_as_sp_from_keyvault_secrets(&self, keyvault_url: &str) -> Result<()> {
        tracing::info!("Retrieving service principal credentials from Key Vault: {}", keyvault_url);
        Ok(())
    }

    async fn list_apps_by_name(&self, app_name: &str) -> Result<Vec<Value>> {
        let output = Command::new("az")
            .args([
                "ad", "app", "list",
                "--filter", &format!("displayname eq '{}'", app_name),
                "-o", "json",
                "--only-show-errors"
            ])
            .output()
            .await
            .context("Failed to list Azure AD applications")?;

        if output.status.success() {
            let apps: Vec<Value> = serde_json::from_slice(&output.stdout)
                .context("Failed to parse Azure AD apps JSON")?;
            Ok(apps)
        } else {
            Ok(vec![])
        }
    }

    async fn create_app_and_sp(&self, app_name: &str) -> Result<()> {
        tracing::info!("Creating Azure AD application: {}", app_name);
        
        let app_output = Command::new("az")
            .args([
                "ad", "app", "create",
                "--display-name", app_name,
                "--only-show-errors"
            ])
            .output()
            .await
            .context("Failed to create Azure AD application")?;

        if !app_output.status.success() {
            anyhow::bail!("Failed to create Azure AD application: {}", String::from_utf8_lossy(&app_output.stderr));
        }

        let app: Value = serde_json::from_slice(&app_output.stdout)
            .context("Failed to parse created app JSON")?;
        
        let app_id = app["appId"].as_str()
            .context("Failed to get appId from created application")?;

        tracing::info!("Creating service principal for app: {}", app_id);
        
        let sp_output = Command::new("az")
            .args([
                "ad", "sp", "create",
                "--id", app_id,
                "--only-show-errors"
            ])
            .output()
            .await
            .context("Failed to create service principal")?;

        if !sp_output.status.success() {
            anyhow::bail!("Failed to create service principal: {}", String::from_utf8_lossy(&sp_output.stderr));
        }

        tracing::info!("Successfully created Azure AD application and service principal");
        Ok(())
    }
}
