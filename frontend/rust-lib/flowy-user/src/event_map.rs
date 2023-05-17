use std::sync::Arc;

use strum_macros::Display;

use flowy_derive::{Flowy_Event, ProtoBuf_Enum};
use flowy_error::FlowyResult;
use lib_dispatch::prelude::*;
use lib_infra::box_any::BoxAny;
use lib_infra::future::{Fut, FutureResult};

use crate::entities::{SignInResponse, SignUpResponse, UpdateUserProfileParams, UserProfile};
use crate::event_handler::*;
use crate::{errors::FlowyError, services::UserSession};

pub fn init(user_session: Arc<UserSession>) -> AFPlugin {
  AFPlugin::new()
    .name("Flowy-User")
    .state(user_session)
    .event(UserEvent::SignIn, sign_in)
    .event(UserEvent::SignUp, sign_up)
    .event(UserEvent::InitUser, init_user_handler)
    .event(UserEvent::GetUserProfile, get_user_profile_handler)
    .event(UserEvent::SignOut, sign_out)
    .event(UserEvent::UpdateUserProfile, update_user_profile_handler)
    .event(UserEvent::CheckUser, check_user_handler)
    .event(UserEvent::SetAppearanceSetting, set_appearance_setting)
    .event(UserEvent::GetAppearanceSetting, get_appearance_setting)
    .event(UserEvent::GetUserSetting, get_user_setting)
}

pub trait UserStatusCallback: Send + Sync + 'static {
  fn did_sign_in(&self, token: &str, user_id: i64) -> Fut<FlowyResult<()>>;
  fn did_sign_up(&self, user_profile: &UserProfile) -> Fut<FlowyResult<()>>;
  fn did_expired(&self, token: &str, user_id: i64) -> Fut<FlowyResult<()>>;
  fn will_migrated(&self, token: &str, old_user_id: &str, user_id: i64) -> Fut<FlowyResult<()>>;
}

/// Provide the generic interface for the user cloud service
/// The user cloud service is responsible for the user authentication and user profile management
pub trait UserCloudService: Send + Sync {
  /// Sign up a new account
  fn sign_up(&self, params: BoxAny) -> FutureResult<SignUpResponse, FlowyError>;

  /// Sign in an account
  fn sign_in(&self, params: BoxAny) -> FutureResult<SignInResponse, FlowyError>;

  /// Sign out an account
  fn sign_out(&self, token: &str) -> FutureResult<(), FlowyError>;

  /// Using the user's token to update the user information
  fn update_user(
    &self,
    token: &str,
    params: UpdateUserProfileParams,
  ) -> FutureResult<(), FlowyError>;

  /// Get the user information using the user's token
  fn get_user(&self, token: &str) -> FutureResult<UserProfile, FlowyError>;
}

#[derive(Clone, Copy, PartialEq, Eq, Debug, Display, Hash, ProtoBuf_Enum, Flowy_Event)]
#[event_err = "FlowyError"]
pub enum UserEvent {
  /// Logging into an account using a register email and password
  #[event(input = "SignInPayloadPB", output = "UserProfilePB")]
  SignIn = 0,

  /// Creating a new account
  #[event(input = "SignUpPayloadPB", output = "UserProfilePB")]
  SignUp = 1,

  /// Logging out fo an account
  #[event(passthrough)]
  SignOut = 2,

  /// Update the user information
  #[event(input = "UpdateUserProfilePayloadPB")]
  UpdateUserProfile = 3,

  /// Get the user information
  #[event(output = "UserProfilePB")]
  GetUserProfile = 4,

  /// Check the user current session is valid or not
  #[event(output = "UserProfilePB")]
  CheckUser = 5,

  /// Initialize resources for the current user after launching the application
  #[event()]
  InitUser = 6,

  /// Change the visual elements of the interface, such as theme, font and more
  #[event(input = "AppearanceSettingsPB")]
  SetAppearanceSetting = 7,

  /// Get the appearance setting
  #[event(output = "AppearanceSettingsPB")]
  GetAppearanceSetting = 8,

  /// Get the settings of the user, such as the user storage folder
  #[event(output = "UserSettingPB")]
  GetUserSetting = 9,
}
