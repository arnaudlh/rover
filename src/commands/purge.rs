use anyhow::Result;
use std::fs;
use crate::config::Config;

pub async fn execute(config: &Config) -> Result<()> {
    tracing::info!("Purging cache folders");

    let tf_cache_folder = config.get_tf_cache_folder();
    let tf_data_dir = config.get_tf_data_dir();

    if tf_cache_folder.exists() {
        tracing::info!("Removing cache folder: {:?}", tf_cache_folder);
        fs::remove_dir_all(&tf_cache_folder)?;
    }

    if tf_data_dir.exists() {
        tracing::info!("Removing data folder: {:?}", tf_data_dir);
        fs::remove_dir_all(&tf_data_dir)?;
    }

    let home_dir = dirs::home_dir().unwrap_or_default();
    let tmp_pattern = format!("{}/*.tmp", home_dir.display());
    
    if let Ok(entries) = glob::glob(&tmp_pattern) {
        for entry in entries.flatten() {
            if entry.exists() {
                tracing::info!("Removing temp file: {:?}", entry);
                fs::remove_file(entry)?;
            }
        }
    }

    tracing::info!("Purge completed");
    Ok(())
}
