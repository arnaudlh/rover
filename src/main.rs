use anyhow::Result;
use clap::Parser;
use rover::{config::Config, logging};

#[tokio::main]
async fn main() -> Result<()> {
    let config = Config::parse();

    logging::init(&config)?;

    tracing::info!("🚀 Starting rover v{}", env!("CARGO_PKG_VERSION"));

    match &config.command {
        Some(cmd) => cmd.execute(&config).await,
        None => {
            println!("🛸 Rover - Terraform wrapper for Azure state management");
            println!("💡 Use --help for available commands");
            Ok(())
        }
    }
}
