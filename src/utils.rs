use anyhow::{Context, Result};
use std::path::Path;
use tokio::time::{sleep, Duration};

pub async fn execute_with_backoff<F, Fut, T>(
    mut operation: F,
    max_retries: u32,
    initial_delay: Duration,
) -> Result<T>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = Result<T>>,
{
    let mut delay = initial_delay;
    let mut last_error = None;

    for attempt in 0..=max_retries {
        match operation().await {
            Ok(result) => return Ok(result),
            Err(error) => {
                last_error = Some(error);
                
                if attempt < max_retries {
                    tracing::warn!("Operation failed on attempt {}, retrying in {:?}", attempt + 1, delay);
                    sleep(delay).await;
                    delay *= 2;
                }
            }
        }
    }

    Err(last_error.unwrap())
}

pub fn expand_path(path: &str) -> Result<String> {
    let expanded = shellexpand::full(path)
        .context("Failed to expand shell variables in path")?;
    Ok(expanded.to_string())
}

pub fn ensure_directory_exists(path: &Path) -> Result<()> {
    if !path.exists() {
        std::fs::create_dir_all(path)
            .context(format!("Failed to create directory: {:?}", path))?;
    }
    Ok(())
}

pub fn generate_job_id() -> String {
    use chrono::Utc;
    let now = Utc::now();
    format!("{}{}", now.format("%Y%m%d%H%M%S"), uuid::Uuid::new_v4().simple().to_string().chars().take(8).collect::<String>())
}

pub fn get_rover_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}
