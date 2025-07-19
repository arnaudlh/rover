use crate::config::Config;
use anyhow::Result;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

pub fn init(config: &Config) -> Result<()> {
    let log_level = match config.log_severity.to_uppercase().as_str() {
        "VERBOSE" => "trace",
        "DEBUG" => "debug",
        "INFO" => "info",
        "WARN" => "warn",
        "ERROR" => "error",
        "FATAL" => "error",
        _ => "info",
    };

    let env_filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(format!("rover={}", log_level)));

    let fmt_layer = tracing_subscriber::fmt::layer()
        .with_target(false)
        .with_thread_ids(false)
        .with_thread_names(false)
        .with_file(true)
        .with_line_number(true);

    tracing_subscriber::registry()
        .with(env_filter)
        .with(fmt_layer)
        .init();

    if config.debug {
        std::env::set_var("TF_LOG", "DEBUG");
        std::env::set_var("TF_LOG_PROVIDER", "DEBUG");
    } else {
        match log_level {
            "trace" => {
                std::env::set_var("TF_LOG", "TRACE");
                std::env::set_var("TF_LOG_PROVIDER", "TRACE");
            }
            "debug" => {
                std::env::set_var("TF_LOG", "DEBUG");
                std::env::set_var("TF_LOG_PROVIDER", "DEBUG");
            }
            "info" => {
                std::env::set_var("TF_LOG", "INFO");
                std::env::set_var("TF_LOG_PROVIDER", "INFO");
            }
            "warn" => {
                std::env::set_var("TF_LOG", "WARN");
                std::env::set_var("TF_LOG_PROVIDER", "WARN");
            }
            "error" => {
                std::env::set_var("TF_LOG", "ERROR");
                std::env::set_var("TF_LOG_PROVIDER", "ERROR");
            }
            _ => {}
        }
    }

    if log_level != "trace" {
        std::env::set_var("TF_IN_AUTOMATION", "true");
    }

    Ok(())
}
