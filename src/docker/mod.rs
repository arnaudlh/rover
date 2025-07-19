use anyhow::{Context, Result};
use tokio::process::Command;

pub struct DockerManager;

impl Default for DockerManager {
    fn default() -> Self {
        Self::new()
    }
}

impl DockerManager {
    pub fn new() -> Self {
        Self
    }

    pub async fn build_image(&self, dockerfile: &str, tag: &str, context: &str) -> Result<()> {
        tracing::info!("Building Docker image: {} with tag: {}", dockerfile, tag);

        let output = Command::new("docker")
            .args(["build", "-f", dockerfile, "-t", tag, context])
            .output()
            .await
            .context("Failed to execute docker build")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("Docker build failed: {}", stderr);
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        tracing::info!("Docker build completed: {}", stdout);

        Ok(())
    }

    pub async fn push_image(&self, tag: &str) -> Result<()> {
        tracing::info!("Pushing Docker image: {}", tag);

        let output = Command::new("docker")
            .args(["push", tag])
            .output()
            .await
            .context("Failed to execute docker push")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("Docker push failed: {}", stderr);
        }

        tracing::info!("Docker push completed for: {}", tag);
        Ok(())
    }
}
