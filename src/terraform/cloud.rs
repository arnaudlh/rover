use crate::config::Config;
use anyhow::{Context, Result};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Serialize, Deserialize)]
pub struct Workspace {
    pub id: String,
    pub name: String,
    pub execution_mode: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct WorkspaceCreateRequest {
    pub data: WorkspaceData,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct WorkspaceData {
    #[serde(rename = "type")]
    pub workspace_type: String,
    pub attributes: WorkspaceAttributes,
    pub relationships: Option<WorkspaceRelationships>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct WorkspaceAttributes {
    pub name: String,
    #[serde(rename = "execution-mode")]
    pub execution_mode: String,
    #[serde(rename = "global-remote-state")]
    pub global_remote_state: bool,
    #[serde(rename = "structured-run-output-enabled")]
    pub structured_run_output_enabled: bool,
    #[serde(rename = "agent-pool-id", skip_serializing_if = "Option::is_none")]
    pub agent_pool_id: Option<String>,
    #[serde(
        rename = "assessments-enabled",
        skip_serializing_if = "Option::is_none"
    )]
    pub assessments_enabled: Option<bool>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct WorkspaceRelationships {
    pub project: Option<ProjectRelationship>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ProjectRelationship {
    pub data: ProjectData,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ProjectData {
    pub id: String,
}

pub struct TerraformCloud {
    client: Client,
    hostname: String,
    organization: String,
    token: String,
}

impl TerraformCloud {
    pub fn new(config: &Config) -> Result<Self> {
        let hostname = config
            .tf_cloud_hostname
            .as_ref()
            .context("Terraform Cloud hostname not configured")?
            .clone();

        let organization = config
            .tf_cloud_organization
            .as_ref()
            .context("Terraform Cloud organization not configured")?
            .clone();

        let token = Self::get_token(&hostname)?;

        Ok(Self {
            client: Client::new(),
            hostname,
            organization,
            token,
        })
    }

    fn get_token(hostname: &str) -> Result<String> {
        let home_dir = dirs::home_dir().context("Could not find home directory")?;
        let credentials_path = home_dir.join(".terraform.d").join("credentials.tfrc.json");

        if !credentials_path.exists() {
            anyhow::bail!("Terraform credentials not found. Run 'terraform login' first.");
        }

        let credentials_content = std::fs::read_to_string(&credentials_path)
            .context("Failed to read Terraform credentials")?;

        let credentials: Value = serde_json::from_str(&credentials_content)
            .context("Failed to parse Terraform credentials")?;

        let token = credentials["credentials"][hostname]["token"]
            .as_str()
            .context("Token not found in credentials")?;

        Ok(token.to_string())
    }

    pub async fn list_workspaces(&self) -> Result<Vec<String>> {
        let url = format!(
            "https://{}/api/v2/organizations/{}/workspaces",
            self.hostname, self.organization
        );

        let response = self
            .client
            .get(&url)
            .header("Authorization", format!("Bearer {}", self.token))
            .header("Content-Type", "application/vnd.api+json")
            .send()
            .await
            .context("Failed to send request to Terraform Cloud")?;

        if !response.status().is_success() {
            anyhow::bail!("Terraform Cloud API error: {}", response.status());
        }

        let body: Value = response
            .json()
            .await
            .context("Failed to parse response JSON")?;

        let workspaces = body["data"]
            .as_array()
            .context("Invalid response format")?
            .iter()
            .filter_map(|w| w["attributes"]["name"].as_str())
            .map(|s| s.to_string())
            .collect();

        Ok(workspaces)
    }

    pub async fn create_workspace(&self, name: &str) -> Result<()> {
        let url = format!(
            "https://{}/api/v2/organizations/{}/workspaces",
            self.hostname, self.organization
        );

        let workspace_request = WorkspaceCreateRequest {
            data: WorkspaceData {
                workspace_type: "workspaces".to_string(),
                attributes: WorkspaceAttributes {
                    name: name.to_string(),
                    execution_mode: "remote".to_string(),
                    global_remote_state: false,
                    structured_run_output_enabled: false,
                    agent_pool_id: None,
                    assessments_enabled: None,
                },
                relationships: None,
            },
        };

        let response = self
            .client
            .post(&url)
            .header("Authorization", format!("Bearer {}", self.token))
            .header("Content-Type", "application/vnd.api+json")
            .json(&workspace_request)
            .send()
            .await
            .context("Failed to send workspace creation request")?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            anyhow::bail!("Failed to create workspace: {} - {}", status, error_text);
        }

        tracing::info!("Workspace '{}' created successfully", name);
        Ok(())
    }

    pub async fn delete_workspace(&self, name: &str) -> Result<()> {
        let url = format!(
            "https://{}/api/v2/organizations/{}/workspaces/{}",
            self.hostname, self.organization, name
        );

        let response = self
            .client
            .delete(&url)
            .header("Authorization", format!("Bearer {}", self.token))
            .header("Content-Type", "application/vnd.api+json")
            .send()
            .await
            .context("Failed to send workspace deletion request")?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            anyhow::bail!("Failed to delete workspace: {} - {}", status, error_text);
        }

        tracing::info!("Workspace '{}' deleted successfully", name);
        Ok(())
    }

    pub async fn get_workspace(&self, name: &str) -> Result<Option<Workspace>> {
        let url = format!(
            "https://{}/api/v2/organizations/{}/workspaces/{}",
            self.hostname, self.organization, name
        );

        let response = self
            .client
            .get(&url)
            .header("Authorization", format!("Bearer {}", self.token))
            .header("Content-Type", "application/vnd.api+json")
            .send()
            .await
            .context("Failed to send workspace get request")?;

        if response.status().as_u16() == 404 {
            return Ok(None);
        }

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            anyhow::bail!("Failed to get workspace: {} - {}", status, error_text);
        }

        let body: Value = response
            .json()
            .await
            .context("Failed to parse response JSON")?;

        let workspace_data = &body["data"];
        let workspace = Workspace {
            id: workspace_data["id"]
                .as_str()
                .unwrap_or_default()
                .to_string(),
            name: workspace_data["attributes"]["name"]
                .as_str()
                .unwrap_or_default()
                .to_string(),
            execution_mode: workspace_data["attributes"]["execution-mode"]
                .as_str()
                .unwrap_or_default()
                .to_string(),
        };

        Ok(Some(workspace))
    }
}
