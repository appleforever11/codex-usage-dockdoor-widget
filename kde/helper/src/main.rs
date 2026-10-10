//! Codex Usage plasmoid helper — the Rust backend for the KDE Plasma port of
//! the DockDoor Codex Usage widget. Modes:
//!
//!   codex-usage-helper daemon [--port N]   long-running snapshot server
//!   codex-usage-helper once                single refresh, print snapshot
//!   codex-usage-helper set-model --model M --reasoning R|low|medium|max
//!   codex-usage-helper doctor              environment diagnostics
//!   codex-usage-helper refresh-account     one account-limit fetch only

mod analytics;
mod codexrpc;
mod httpfetch;
mod modelsettings;
mod server;
mod sessions;
mod settings;
mod snapshot;
mod telemetry;
mod transcript;
mod usage;
mod usagefile;
mod util;

use settings::Settings;
use std::sync::Arc;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mode = args.first().map(|s| s.as_str()).unwrap_or("daemon");
    let mut port_override: Option<u16> = None;
    let mut flag_model: Option<String> = None;
    let mut flag_reasoning: Option<String> = None;
    let mut flag_fast: Option<bool> = None;

    let mut index = 1;
    while index < args.len() {
        match args[index].as_str() {
            "--port" => {
                port_override = args.get(index + 1).and_then(|v| v.parse().ok());
                index += 2;
            }
            "--model" => {
                flag_model = args.get(index + 1).cloned();
                index += 2;
            }
            "--reasoning" => {
                flag_reasoning = args.get(index + 1).cloned();
                index += 2;
            }
            "--fast" | "--speed" => {
                flag_fast = Some(true);
                index += 1;
            }
            "--no-fast" => {
                flag_fast = Some(false);
                index += 1;
            }
            other => {
                eprintln!("unknown flag: {other}");
                std::process::exit(2);
            }
        }
    }

    let mut settings = Settings::load();
    if let Some(port) = port_override {
        settings.port = port;
    }
    if settings.sessions_folder == "~/.codex/sessions" {
        let default = usagefile::default_sessions_folder();
        if default != settings.sessions_folder {
            settings.sessions_folder = default;
        }
    }

    match mode {
        "daemon" => run_daemon(settings),
        "once" => run_once_mode(settings),
        "set-model" => run_set_model(flag_model, flag_reasoning, flag_fast),
        "refresh-account" => run_refresh_account(&settings),
        "doctor" => run_doctor(&settings),
        "help" | "--help" | "-h" => print_help(),
        other => {
            eprintln!("unknown mode: {other}");
            print_help();
            std::process::exit(2);
        }
    }
}

fn print_help() {
    println!(
        "codex-usage-helper {} — Codex Usage plasmoid backend\n\
         \n\
         Modes:\n\
           daemon          serve snapshots on 127.0.0.1 (default)\n\
           once            build one snapshot, print it, exit\n\
           set-model       write ~/.codex/config.toml defaults\n\
           refresh-account fetch account limits into the usage file\n\
           doctor          print environment diagnostics\n\
         \n\
         Flags:\n\
           --port N        override the HTTP port\n\
           --model M       model id for set-model\n\
           --reasoning R   low | medium | high | xhigh | max | ultra\n\
           --fast          enable the fast speed tier (like /fast)\n\
           --no-fast       disable the fast speed tier",
        settings::HELPER_VERSION
    );
}

fn run_daemon(settings: Settings) {
    let state = Arc::new(server::AppState::new(settings));

    // First refresh synchronously so the plasmoid has data immediately, then
    // keep serving while the loop re-refreshes on its interval.
    {
        let state = state.clone();
        std::thread::spawn(move || {
            state.refresh_now();
        });
    }

    let serve_state = state.clone();
    let _server_handle = std::thread::spawn(move || {
        if let Err(error) = server::serve(serve_state.clone()) {
            eprintln!("helper server error: {error}");
            std::process::exit(1);
        }
    });

    loop {
        let interval = {
            let guard = state
                .settings
                .lock()
                .map(|settings| settings.refresh_seconds)
                .unwrap_or(60);
            guard.max(15)
        };
        state.wait_for_refresh_signal(std::time::Duration::from_secs(interval));
        state.refresh_now();
    }

}

fn run_once_mode(settings: Settings) {
    let (built, fetch) = server::run_once(&settings);
    if let Some(error) = fetch.error {
        eprintln!("warning: account fetch failed: {error}");
    }
    println!(
        "{}",
        serde_json::to_string_pretty(&built).unwrap_or_default()
    );
}

fn run_set_model(model: Option<String>, reasoning: Option<String>, fast: Option<bool>) {
    let (Some(model), Some(reasoning)) = (model, reasoning) else {
        eprintln!("set-model requires --model and --reasoning");
        std::process::exit(2);
    };
    let catalog = modelsettings::fallback_catalog();
    match modelsettings::update(
        &model,
        &util::normalized_reasoning_effort(&reasoning),
        fast,
        &catalog,
    ) {
        Ok(updated) => println!(
            "New chat defaults: {} ({}){}",
            updated.short_model_name,
            updated.reasoning_label,
            if updated.fast { " · Fast" } else { "" }
        ),
        Err(error) => {
            eprintln!("couldn't save defaults: {error}");
            std::process::exit(1);
        }
    }
}

fn run_refresh_account(settings: &Settings) {
    let fetch = snapshot::refresh_account_limits(settings);
    match fetch.error {
        Some(error) => {
            eprintln!("account refresh failed: {error}");
            std::process::exit(1);
        }
        None => println!("Account limits refreshed into {}", settings.usage_state_path),
    }
}

fn run_doctor(settings: &Settings) {
    println!("codex-usage-helper {}", settings::HELPER_VERSION);
    println!("codex home:      {}", settings::codex_home().display());
    println!("sessions folder: {}", settings.sessions_root().display());
    println!("usage file:      {}", settings.usage_state_path_expanded().display());
    println!("config.toml:     {}", modelsettings::config_path().display());
    println!("helper config:   {}", Settings::config_path().display());
    println!("state folder:    {}", settings::state_root().display());
    println!(
        "codex binary:    {}",
        codexrpc::find_codex_binary().unwrap_or_else(|| "NOT FOUND".to_string())
    );
    println!("model defaults:  {:?}", modelsettings::read());
    println!(
        "sessions found:  {}",
        sessions::session_files(&settings.sessions_root()).len()
    );
    println!("port:            {}", settings.port);
    println!("refresh seconds: {}", settings.refresh_seconds);
    println!("chat viewer:     {}", settings.chat_viewer_command);
}
