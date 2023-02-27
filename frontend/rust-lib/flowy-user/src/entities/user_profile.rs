use crate::errors::ErrorCode;
use flowy_derive::ProtoBuf;
use std::convert::TryInto;
use user_model::{
  UpdateUserProfileParams, UserEmail, UserIcon, UserId, UserName, UserOpenaiKey, UserPassword,
  UserProfile,
};

#[derive(Default, ProtoBuf)]
pub struct UserTokenPB {
  #[pb(index = 1)]
  pub token: String,
}

#[derive(ProtoBuf, Default, Clone)]
pub struct UserSettingPB {
  #[pb(index = 1)]
  pub(crate) user_folder: String,
}

#[derive(ProtoBuf, Default, Debug, PartialEq, Eq, Clone)]
pub struct UserProfilePB {
  #[pb(index = 1)]
  pub id: String,

  #[pb(index = 2)]
  pub email: String,

  #[pb(index = 3)]
  pub name: String,

  #[pb(index = 4)]
  pub token: String,

  #[pb(index = 5)]
  pub icon_url: String,

  #[pb(index = 6)]
  pub openai_key: String,
}

impl std::convert::From<UserProfile> for UserProfilePB {
  fn from(user_profile: UserProfile) -> Self {
    Self {
      id: user_profile.id,
      email: user_profile.email,
      name: user_profile.name,
      token: user_profile.token,
      icon_url: user_profile.icon_url,
      openai_key: user_profile.openai_key,
    }
  }
}

#[derive(ProtoBuf, Default)]
pub struct UpdateUserProfilePayloadPB {
  #[pb(index = 1)]
  pub id: String,

  #[pb(index = 2, one_of)]
  pub name: Option<String>,

  #[pb(index = 3, one_of)]
  pub email: Option<String>,

  #[pb(index = 4, one_of)]
  pub password: Option<String>,

  #[pb(index = 5, one_of)]
  pub icon_url: Option<String>,

  #[pb(index = 6, one_of)]
  pub openai_key: Option<String>,
}

impl UpdateUserProfilePayloadPB {
  pub fn new(id: &str) -> Self {
    Self {
      id: id.to_owned(),
      ..Default::default()
    }
  }

  pub fn name(mut self, name: &str) -> Self {
    self.name = Some(name.to_owned());
    self
  }

  pub fn email(mut self, email: &str) -> Self {
    self.email = Some(email.to_owned());
    self
  }

  pub fn password(mut self, password: &str) -> Self {
    self.password = Some(password.to_owned());
    self
  }

  pub fn icon_url(mut self, icon_url: &str) -> Self {
    self.icon_url = Some(icon_url.to_owned());
    self
  }

  pub fn openai_key(mut self, openai_key: &str) -> Self {
    self.openai_key = Some(openai_key.to_owned());
    self
  }
}

impl TryInto<UpdateUserProfileParams> for UpdateUserProfilePayloadPB {
  type Error = ErrorCode;

  fn try_into(self) -> Result<UpdateUserProfileParams, Self::Error> {
    let id = UserId::parse(self.id)?.0;

    let name = match self.name {
      None => None,
      Some(name) => Some(UserName::parse(name)?.0),
    };

    let email = match self.email {
      None => None,
      Some(email) => Some(UserEmail::parse(email)?.0),
    };

    let password = match self.password {
      None => None,
      Some(password) => Some(UserPassword::parse(password)?.0),
    };

    let icon_url = match self.icon_url {
      None => None,
      Some(icon_url) => Some(UserIcon::parse(icon_url)?.0),
    };

    let openai_key = match self.openai_key {
      None => None,
      Some(openai_key) => Some(UserOpenaiKey::parse(openai_key)?.0),
    };

    Ok(UpdateUserProfileParams {
      id,
      name,
      email,
      password,
      icon_url,
      openai_key,
    })
  }
}
