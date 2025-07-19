use crate::{commands::WorkspaceAction, config::Config, terraform::cloud::TerraformCloud};
use anyhow::Result;

pub async fn execute(config: &Config, action: &Option<WorkspaceAction>) -> Result<()> {
    match action {
        Some(WorkspaceAction::List) => {
            tracing::info!("Listing workspaces");

            if config.backend_type == "remote" {
                let tf_cloud = TerraformCloud::new(config)?;
                let workspaces = tf_cloud.list_workspaces().await?;

                println!("Terraform Cloud workspaces:");
                for workspace in workspaces {
                    println!("  - {}", workspace);
                }
            } else {
                println!("Workspace listing is only available for Terraform Cloud backend");
            }

            Ok(())
        }
        Some(WorkspaceAction::Create { name }) => {
            tracing::info!("Creating workspace: {}", name);

            if config.backend_type == "remote" {
                let tf_cloud = TerraformCloud::new(config)?;
                tf_cloud.create_workspace(name).await?;
                println!("Workspace '{}' created successfully", name);
            } else {
                println!("Workspace creation is only available for Terraform Cloud backend");
            }

            Ok(())
        }
        Some(WorkspaceAction::Delete { name }) => {
            tracing::info!("Deleting workspace: {}", name);

            if config.backend_type == "remote" {
                let tf_cloud = TerraformCloud::new(config)?;
                tf_cloud.delete_workspace(name).await?;
                println!("Workspace '{}' deleted successfully", name);
            } else {
                println!("Workspace deletion is only available for Terraform Cloud backend");
            }

            Ok(())
        }
        None => {
            println!("rover workspace [list|create|delete]");
            Ok(())
        }
    }
}
