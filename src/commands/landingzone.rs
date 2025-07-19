use crate::{commands::LandingzoneAction, config::Config};
use anyhow::Result;

pub async fn execute(_config: &Config, action: &Option<LandingzoneAction>) -> Result<()> {
    match action {
        Some(LandingzoneAction::List) => {
            tracing::info!("Listing deployed landing zones");
            println!("Deployed landing zones:");
            Ok(())
        }
        None => {
            println!("rover landingzone [list]");
            Ok(())
        }
    }
}
