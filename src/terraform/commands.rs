use crate::config::Config;
use anyhow::{Context, Result};
use std::path::Path;
use tokio::process::Command;

pub async fn terraform_init(_config: &Config, landingzone_path: &str) -> Result<()> {
    tracing::info!("🏗️ Initializing Terraform in: {}", landingzone_path);

    let mut cmd = Command::new("terraform");
    cmd.arg("init").current_dir(landingzone_path);

    let output = cmd
        .output()
        .await
        .context("Failed to execute terraform init")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Terraform init failed: {}", stderr);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    tracing::info!("✅ Terraform init completed: {}", stdout);

    Ok(())
}

pub async fn terraform_plan(
    config: &Config,
    landingzone_path: &str,
    plan_file: &Option<String>,
    var_files: &[String],
    var_folder: &Option<String>,
    parallelism: Option<u32>,
    compact_warnings: bool,
) -> Result<()> {
    tracing::info!("📋 Running Terraform plan in: {}", landingzone_path);

    let tf_data_dir = config.get_tf_data_dir();
    let workspace = config.get_workspace();
    let level = config.get_level();
    let tf_name = config.get_tf_name();
    let tf_plan = config.get_tf_plan();

    let state_path = tf_data_dir
        .join("tfstates")
        .join(&level)
        .join(&workspace)
        .join(&tf_name);
    let plan_path = tf_data_dir
        .join("tfstates")
        .join(&level)
        .join(&workspace)
        .join(&tf_plan);

    std::fs::create_dir_all(state_path.parent().unwrap())
        .context("Failed to create state directory")?;

    let mut cmd = Command::new("terraform");
    cmd.arg("plan")
        .arg("-refresh=true")
        .arg("-lock=false")
        .arg(format!("-state={}", state_path.display()))
        .arg(format!("-out={}", plan_path.display()))
        .current_dir(landingzone_path);

    if config.tf_no_color {
        cmd.arg("-no-color");
    }

    if compact_warnings {
        cmd.arg("-compact-warnings");
    }

    if let Some(p) = parallelism {
        cmd.arg(format!("-parallelism={}", p));
    }

    for var_file in var_files {
        cmd.arg(format!("-var-file={}", var_file));
    }

    if let Some(folder) = var_folder {
        expand_tfvars_folder(&mut cmd, folder)?;
    }

    let output = cmd
        .output()
        .await
        .context("Failed to execute terraform plan")?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    match output.status.code() {
        Some(0) => {
            tracing::info!("✅ Terraform plan succeeded");
            println!("{}", stdout);
        }
        Some(1) => {
            tracing::error!("❌ Terraform plan failed: {}", stderr);
            anyhow::bail!("Terraform plan failed: {}", stderr);
        }
        Some(2) => {
            tracing::info!("✅ Terraform plan succeeded with non-empty diff");
            println!("{}", stdout);
        }
        _ => {
            anyhow::bail!("Terraform plan failed with unknown exit code");
        }
    }

    if let Some(output_file) = plan_file {
        if plan_path.exists() {
            std::fs::copy(&plan_path, output_file).context("Failed to copy plan file")?;
            tracing::info!("Plan file copied to: {}", output_file);
        }
    }

    Ok(())
}

pub async fn terraform_apply(
    config: &Config,
    landingzone_path: &str,
    plan_file: &Option<String>,
) -> Result<()> {
    tracing::info!("🚀 Running Terraform apply in: {}", landingzone_path);

    let tf_data_dir = config.get_tf_data_dir();
    let workspace = config.get_workspace();
    let level = config.get_level();
    let tf_name = config.get_tf_name();
    let tf_plan = config.get_tf_plan();

    let state_path = tf_data_dir
        .join("tfstates")
        .join(&level)
        .join(&workspace)
        .join(&tf_name);

    let mut cmd = Command::new("terraform");
    cmd.arg("apply")
        .arg(format!("-state={}", state_path.display()))
        .current_dir(landingzone_path);

    match config.backend_type.as_str() {
        "azurerm" => {
            let plan_path = plan_file
                .as_ref()
                .map(|p| Path::new(p).to_path_buf())
                .unwrap_or_else(|| {
                    tf_data_dir
                        .join("tfstates")
                        .join(&level)
                        .join(&workspace)
                        .join(&tf_plan)
                });

            if !plan_path.exists() {
                tracing::info!("Plan file not found, running terraform plan first");
                terraform_plan(config, landingzone_path, &None, &[], &None, None, false).await?;
            }

            cmd.arg(plan_path.to_string_lossy().as_ref());
        }
        "remote" => {}
        _ => {}
    }

    let output = cmd
        .output()
        .await
        .context("Failed to execute terraform apply")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Terraform apply failed: {}", stderr);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    tracing::info!("Terraform apply completed: {}", stdout);
    println!("{}", stdout);

    Ok(())
}

pub async fn terraform_destroy(
    config: &Config,
    landingzone_path: &str,
    var_files: &[String],
    var_folder: &Option<String>,
    parallelism: Option<u32>,
) -> Result<()> {
    tracing::info!("Running Terraform destroy in: {}", landingzone_path);

    let tf_data_dir = config.get_tf_data_dir();
    let workspace = config.get_workspace();
    let level = config.get_level();
    let tf_name = config.get_tf_name();

    let state_path = tf_data_dir
        .join("tfstates")
        .join(&level)
        .join(&workspace)
        .join(&tf_name);

    let mut cmd = Command::new("terraform");
    cmd.arg("destroy")
        .arg("-auto-approve")
        .arg(format!("-state={}", state_path.display()))
        .current_dir(landingzone_path);

    if let Some(p) = parallelism {
        cmd.arg(format!("-parallelism={}", p));
    }

    for var_file in var_files {
        cmd.arg(format!("-var-file={}", var_file));
    }

    if let Some(folder) = var_folder {
        expand_tfvars_folder(&mut cmd, folder)?;
    }

    let output = cmd
        .output()
        .await
        .context("Failed to execute terraform destroy")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Terraform destroy failed: {}", stderr);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    tracing::info!("Terraform destroy completed: {}", stdout);
    println!("{}", stdout);

    Ok(())
}

pub async fn terraform_validate(_config: &Config, landingzone_path: &str) -> Result<()> {
    tracing::info!("Running Terraform validate in: {}", landingzone_path);

    let output = Command::new("terraform")
        .arg("validate")
        .current_dir(landingzone_path)
        .output()
        .await
        .context("Failed to execute terraform validate")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Terraform validate failed: {}", stderr);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    tracing::info!("Terraform validate completed: {}", stdout);
    println!("{}", stdout);

    Ok(())
}

pub async fn terraform_refresh(
    config: &Config,
    landingzone_path: &str,
    var_files: &[String],
    var_folder: &Option<String>,
) -> Result<()> {
    tracing::info!("Running Terraform refresh in: {}", landingzone_path);

    let tf_data_dir = config.get_tf_data_dir();
    let workspace = config.get_workspace();
    let level = config.get_level();
    let tf_name = config.get_tf_name();

    let state_path = tf_data_dir
        .join("tfstates")
        .join(&level)
        .join(&workspace)
        .join(&tf_name);

    let mut cmd = Command::new("terraform");
    cmd.arg("refresh")
        .arg(format!("-state={}", state_path.display()))
        .current_dir(landingzone_path);

    for var_file in var_files {
        cmd.arg(format!("-var-file={}", var_file));
    }

    if let Some(folder) = var_folder {
        expand_tfvars_folder(&mut cmd, folder)?;
    }

    let output = cmd
        .output()
        .await
        .context("Failed to execute terraform refresh")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Terraform refresh failed: {}", stderr);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    tracing::info!("Terraform refresh completed: {}", stdout);
    println!("{}", stdout);

    Ok(())
}

pub async fn terraform_graph(_config: &Config, landingzone_path: &str) -> Result<()> {
    tracing::info!("Running Terraform graph in: {}", landingzone_path);

    let output = Command::new("terraform")
        .arg("graph")
        .current_dir(landingzone_path)
        .output()
        .await
        .context("Failed to execute terraform graph")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Terraform graph failed: {}", stderr);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    println!("{}", stdout);

    Ok(())
}

pub async fn terraform_output(config: &Config, landingzone_path: &str) -> Result<()> {
    tracing::info!("Running Terraform output in: {}", landingzone_path);

    let tf_data_dir = config.get_tf_data_dir();
    let workspace = config.get_workspace();
    let level = config.get_level();
    let tf_name = config.get_tf_name();

    let state_path = tf_data_dir
        .join("tfstates")
        .join(&level)
        .join(&workspace)
        .join(&tf_name);

    let output = Command::new("terraform")
        .arg("output")
        .arg(format!("-state={}", state_path.display()))
        .current_dir(landingzone_path)
        .output()
        .await
        .context("Failed to execute terraform output")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Terraform output failed: {}", stderr);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    println!("{}", stdout);

    Ok(())
}

pub async fn terraform_show(
    _config: &Config,
    landingzone_path: &str,
    plan_file: &Option<String>,
) -> Result<()> {
    tracing::info!("Running Terraform show in: {}", landingzone_path);

    let mut cmd = Command::new("terraform");
    cmd.arg("show").current_dir(landingzone_path);

    if let Some(plan) = plan_file {
        cmd.arg(plan);
    }

    let output = cmd
        .output()
        .await
        .context("Failed to execute terraform show")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Terraform show failed: {}", stderr);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    println!("{}", stdout);

    Ok(())
}

pub async fn terraform_migrate(_config: &Config, landingzone_path: &str) -> Result<()> {
    tracing::info!("Running Terraform migration in: {}", landingzone_path);

    Ok(())
}

fn expand_tfvars_folder(cmd: &mut Command, folder: &str) -> Result<()> {
    let folder_path = Path::new(folder);

    if !folder_path.exists() {
        anyhow::bail!("Folder {} does not exist", folder);
    }

    let mut found_files = false;

    if let Ok(entries) = std::fs::read_dir(folder_path) {
        for entry in entries.flatten() {
            let path = entry.path();
            if let Some(extension) = path.extension() {
                if extension == "tfvars" || extension == "json" {
                    if let Some(filename) = path.file_name() {
                        if filename.to_string_lossy().ends_with(".tfvars")
                            || filename.to_string_lossy().ends_with(".tfvars.json")
                        {
                            cmd.arg(format!("-var-file={}", path.display()));
                            found_files = true;
                        }
                    }
                }
            }
        }
    }

    if !found_files {
        anyhow::bail!("Folder {} does not have any tfvars files", folder);
    }

    Ok(())
}
