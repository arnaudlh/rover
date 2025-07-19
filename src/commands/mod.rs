use anyhow::Result;
use clap::Subcommand;

use crate::config::Config;

pub mod bootstrap;
pub mod init;
pub mod landingzone;
pub mod launchpad;
pub mod login;
pub mod logout;
pub mod purge;
pub mod workspace;

#[derive(Subcommand, Debug, Clone)]
pub enum Commands {
    Bootstrap {
        #[arg(long)]
        aad_app_name: Option<String>,
        #[arg(long)]
        gitops_pipelines: Option<String>,
        #[arg(long)]
        gitops_agent_pool_execution_mode: Option<String>,
        #[arg(long)]
        bootstrap_script: Option<String>,
    },
    Init {
        landingzone_path: String,
        #[arg(long)]
        plan: bool,
        #[arg(long)]
        apply: bool,
        #[arg(long)]
        destroy: bool,
        #[arg(long)]
        validate: bool,
        #[arg(long)]
        refresh: bool,
        #[arg(long)]
        graph: bool,
        #[arg(long)]
        import: bool,
        #[arg(long)]
        output: bool,
        #[arg(long)]
        taint: bool,
        #[arg(long)]
        untaint: bool,
        #[arg(long)]
        state_list: bool,
        #[arg(long)]
        state_rm: bool,
        #[arg(long)]
        state_show: bool,
        #[arg(long)]
        show: bool,
        #[arg(long)]
        migrate: bool,
        #[arg(short = 'p', long)]
        plan_file: Option<String>,
        #[arg(long)]
        var_file: Vec<String>,
        #[arg(long)]
        var_folder: Option<String>,
        #[arg(long)]
        parallelism: Option<u32>,
        #[arg(long)]
        compact_warnings: bool,
        #[arg(long)]
        launchpad: bool,
    },
    Landingzone {
        #[command(subcommand)]
        action: Option<LandingzoneAction>,
    },
    Launchpad {
        landingzone_path: String,
        #[arg(long)]
        plan: bool,
        #[arg(long)]
        apply: bool,
        #[arg(long)]
        destroy: bool,
    },
    Login {
        #[arg(long)]
        tenant: Option<String>,
        #[arg(long)]
        subscription: Option<String>,
    },
    Logout,
    Purge,
    Workspace {
        #[command(subcommand)]
        action: Option<WorkspaceAction>,
    },
}

#[derive(Subcommand, Debug, Clone)]
pub enum LandingzoneAction {
    List,
}

#[derive(Subcommand, Debug, Clone)]
pub enum WorkspaceAction {
    List,
    Create { name: String },
    Delete { name: String },
}

impl Commands {
    pub async fn execute(&self, config: &Config) -> Result<()> {
        match self {
            Commands::Bootstrap {
                aad_app_name,
                gitops_pipelines,
                gitops_agent_pool_execution_mode,
                bootstrap_script,
            } => {
                bootstrap::execute(
                    config,
                    aad_app_name,
                    gitops_pipelines,
                    gitops_agent_pool_execution_mode,
                    bootstrap_script,
                )
                .await
            }
            Commands::Init {
                landingzone_path,
                plan,
                apply,
                destroy,
                validate,
                refresh,
                graph,
                import,
                output,
                taint,
                untaint,
                state_list,
                state_rm,
                state_show,
                show,
                migrate,
                plan_file,
                var_file,
                var_folder,
                parallelism,
                compact_warnings,
                launchpad,
            } => {
                init::execute(
                    config,
                    landingzone_path,
                    *plan,
                    *apply,
                    *destroy,
                    *validate,
                    *refresh,
                    *graph,
                    *import,
                    *output,
                    *taint,
                    *untaint,
                    *state_list,
                    *state_rm,
                    *state_show,
                    *show,
                    *migrate,
                    plan_file,
                    var_file,
                    var_folder,
                    *parallelism,
                    *compact_warnings,
                    *launchpad,
                )
                .await
            }
            Commands::Landingzone { action } => landingzone::execute(config, action).await,
            Commands::Launchpad {
                landingzone_path,
                plan,
                apply,
                destroy,
            } => launchpad::execute(config, landingzone_path, *plan, *apply, *destroy).await,
            Commands::Login {
                tenant,
                subscription,
            } => login::execute(config, tenant, subscription).await,
            Commands::Logout => logout::execute(config).await,
            Commands::Purge => purge::execute(config).await,
            Commands::Workspace { action } => workspace::execute(config, action).await,
        }
    }
}
