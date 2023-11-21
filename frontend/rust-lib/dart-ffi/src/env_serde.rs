use serde::Deserialize;

use flowy_server_config::af_cloud_config::AFCloudConfiguration;
use flowy_server_config::supabase_config::SupabaseConfiguration;
use flowy_server_config::AuthenticatorType;

#[derive(Deserialize, Debug)]
pub struct AppFlowyDartConfiguration {
  /// This path will be used to store the user data
  pub custom_app_path: String,
  pub origin_app_path: String,
  pub device_id: String,
  pub cloud_type: AuthenticatorType,
  pub(crate) supabase_config: SupabaseConfiguration,
  pub(crate) appflowy_cloud_config: AFCloudConfiguration,
}

impl AppFlowyDartConfiguration {
  pub fn from_str(s: &str) -> Self {
    serde_json::from_str::<AppFlowyDartConfiguration>(s).unwrap()
  }

  /// Parse the environment variable from the frontend application. The frontend will
  /// pass the environment variable as a json string after launching.
  pub fn write_env_from(env_str: &str) {
    let configuration = Self::from_str(env_str);
    configuration.cloud_type.write_env();
    let is_valid = configuration.appflowy_cloud_config.write_env().is_ok();
    // Note on Configuration Priority:
    // If both Supabase config and AppFlowy cloud config are provided in the '.env' file,
    // the AppFlowy cloud config will be prioritized and the Supabase config ignored.
    // Ensure only one of these configurations is active at any given time.
    if !is_valid {
      let _ = configuration.supabase_config.write_env();
    }
  }
}
