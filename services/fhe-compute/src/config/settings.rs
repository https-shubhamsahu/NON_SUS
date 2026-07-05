use serde::Deserialize;

#[derive(Debug, Deserialize, Clone)]
pub struct Server {
    pub port: u16,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Security {
    pub service_token: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Settings {
    pub server: Server,
    pub security: Security,
}

impl Settings {
    pub fn new() -> Result<Self, config::ConfigError> {
        let run_mode = std::env::var("RUN_MODE").unwrap_or_else(|_| "development".into());

        let s = config::Config::builder()
            // Start with development defaults
            .set_default("server.port", 8080)?
            .set_default("security.service_token", "default-secure-fhe-token")?
            // Add environment variables (e.g. FHE_SERVER__PORT=8080)
            .add_source(config::Environment::with_prefix("FHE").separator("__"))
            // Override with local config file if present
            .add_source(config::File::with_name(&format!("config/{}", run_mode)).required(false))
            .build()?;

        s.try_deserialize()
    }
}
