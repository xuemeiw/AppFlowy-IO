use crate::chat_manager::ChatUserService;
use crate::entities::{
  ChatStatePB, LocalAIPluginStatePB, LocalModelResourcePB, ModelTypePB, RunningStatePB,
};
use crate::local_ai::local_llm_resource::{LLMResourceController, LLMResourceService};
use crate::notification::{send_notification, ChatNotification, APPFLOWY_AI_NOTIFICATION_KEY};
use anyhow::Error;
use appflowy_local_ai::chat_plugin::{AIPluginConfig, LocalChatLLMChat};
use appflowy_plugin::manager::PluginManager;
use appflowy_plugin::util::is_apple_silicon;
use flowy_chat_pub::cloud::{AppFlowyAIPlugin, ChatCloudService, LLMModel, LocalAIConfig};
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite::kv::KVStorePreferences;
use futures::Sink;
use lib_infra::async_trait::async_trait;

use serde::{Deserialize, Serialize};
use std::ops::Deref;

use parking_lot::Mutex;
use std::sync::Arc;
use tokio_stream::StreamExt;
use tracing::{debug, error, info, trace};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LLMSetting {
  pub plugin: AppFlowyAIPlugin,
  pub llm_model: LLMModel,
}

pub struct LLMModelInfo {
  pub selected_model: LLMModel,
  pub models: Vec<LLMModel>,
}

const APPFLOWY_LOCAL_AI_ENABLED: &str = "appflowy_local_ai_enabled";
const APPFLOWY_LOCAL_AI_CHAT_ENABLED: &str = "appflowy_local_ai_chat_enabled";
const LOCAL_AI_SETTING_KEY: &str = "appflowy_local_ai_setting:v0";

pub struct LocalAIController {
  llm_chat: Arc<LocalChatLLMChat>,
  llm_res: Arc<LLMResourceController>,
  current_chat_id: Mutex<Option<String>>,
  store_preferences: Arc<KVStorePreferences>,
}

impl Deref for LocalAIController {
  type Target = Arc<LocalChatLLMChat>;

  fn deref(&self) -> &Self::Target {
    &self.llm_chat
  }
}

impl LocalAIController {
  pub fn new(
    plugin_manager: Arc<PluginManager>,
    store_preferences: Arc<KVStorePreferences>,
    user_service: Arc<dyn ChatUserService>,
    cloud_service: Arc<dyn ChatCloudService>,
  ) -> Self {
    let llm_chat = Arc::new(LocalChatLLMChat::new(plugin_manager));
    let mut rx = llm_chat.subscribe_running_state();

    let _weak_store_preferences = Arc::downgrade(&store_preferences);
    tokio::spawn(async move {
      while let Some(state) = rx.next().await {
        info!("[AI Plugin] state: {:?}", state);
        let new_state = RunningStatePB::from(state);
        send_notification(
          APPFLOWY_AI_NOTIFICATION_KEY,
          ChatNotification::UpdateChatPluginState,
        )
        .payload(LocalAIPluginStatePB { state: new_state })
        .send();
      }
    });

    let res_impl = LLMResourceServiceImpl {
      user_service: user_service.clone(),
      cloud_service,
      store_preferences: store_preferences.clone(),
    };

    let (tx, mut rx) = tokio::sync::mpsc::channel(1);
    let llm_res = Arc::new(LLMResourceController::new(user_service, res_impl, tx));

    let cloned_llm_chat = llm_chat.clone();
    let cloned_llm_res = llm_res.clone();
    tokio::spawn(async move {
      while rx.recv().await.is_some() {
        if let Ok(chat_config) = cloned_llm_res.get_ai_plugin_config() {
          if let Err(err) = initialize_chat_plugin(&cloned_llm_chat, chat_config) {
            error!("[AI Plugin] failed to setup plugin: {:?}", err);
          }
        }
      }
    });

    Self {
      llm_chat,
      llm_res,
      current_chat_id: Default::default(),
      store_preferences,
    }
  }
  pub async fn refresh(&self) -> FlowyResult<LLMModelInfo> {
    self.llm_res.refresh_llm_resource().await
  }

  pub fn initialize_chat_plugin(
    &self,
    ret: Option<tokio::sync::oneshot::Sender<()>>,
  ) -> FlowyResult<()> {
    let mut chat_config = self.llm_res.get_ai_plugin_config()?;
    let llm_chat = self.llm_chat.clone();

    tokio::spawn(async move {
      trace!("[AI Plugin] config: {:?}", chat_config);
      if is_apple_silicon().await.unwrap_or(false) {
        chat_config = chat_config.with_device("gpu");
      }
      match llm_chat.init_chat_plugin(chat_config).await {
        Ok(_) => {
          send_notification(
            APPFLOWY_AI_NOTIFICATION_KEY,
            ChatNotification::UpdateChatPluginState,
          )
          .payload(ChatStatePB {
            model_type: ModelTypePB::LocalAI,
            available: true,
          });
        },
        Err(err) => {
          send_notification(
            APPFLOWY_AI_NOTIFICATION_KEY,
            ChatNotification::UpdateChatPluginState,
          )
          .payload(ChatStatePB {
            model_type: ModelTypePB::LocalAI,
            available: false,
          });
          error!("[AI Plugin] failed to setup plugin: {:?}", err);
        },
      }
      if let Some(ret) = ret {
        let _ = ret.send(());
      }
    });
    Ok(())
  }

  /// Returns true if the local AI is enabled and ready to use.
  pub fn can_init(&self) -> bool {
    self.is_enabled() && self.llm_res.is_resource_ready()
  }

  pub fn is_running(&self) -> bool {
    self.llm_chat.get_plugin_running_state().is_ready()
  }

  pub fn is_enabled(&self) -> bool {
    self.store_preferences.get_bool(APPFLOWY_LOCAL_AI_ENABLED)
  }

  pub fn is_chat_enabled(&self) -> bool {
    self
      .store_preferences
      .get_bool(APPFLOWY_LOCAL_AI_CHAT_ENABLED)
  }

  pub fn open_chat(&self, chat_id: &str) {
    if !self.is_running() {
      return;
    }

    // Only keep one chat open at a time. Since loading multiple models at the same time will cause
    // memory issues.
    if let Some(current_chat_id) = self.current_chat_id.lock().as_ref() {
      debug!("[AI Plugin] close previous chat: {}", current_chat_id);
      self.close_chat(current_chat_id);
    }

    *self.current_chat_id.lock() = Some(chat_id.to_string());
    let chat_id = chat_id.to_string();
    let weak_ctrl = Arc::downgrade(&self.llm_chat);
    tokio::spawn(async move {
      if let Some(ctrl) = weak_ctrl.upgrade() {
        if let Err(err) = ctrl.create_chat(&chat_id).await {
          error!("[AI Plugin] failed to open chat: {:?}", err);
        }
      }
    });
  }

  pub fn close_chat(&self, chat_id: &str) {
    let weak_ctrl = Arc::downgrade(&self.llm_chat);
    let chat_id = chat_id.to_string();
    tokio::spawn(async move {
      if let Some(ctrl) = weak_ctrl.upgrade() {
        if let Err(err) = ctrl.close_chat(&chat_id).await {
          error!("[AI Plugin] failed to close chat: {:?}", err);
        }
      }
    });
  }

  pub async fn select_local_llm(&self, llm_id: i64) -> FlowyResult<LocalModelResourcePB> {
    if !self.is_enabled() {
      return Err(FlowyError::local_ai_unavailable());
    }

    let llm_chat = self.llm_chat.clone();
    match llm_chat.destroy_chat_plugin().await {
      Ok(_) => info!("[AI Plugin] destroy plugin successfully"),
      Err(err) => error!("[AI Plugin] failed to destroy plugin: {:?}", err),
    }
    let state = self.llm_res.use_local_llm(llm_id)?;
    // Re-initialize the plugin if the setting is updated and ready to use
    if self.llm_res.is_resource_ready() {
      self.initialize_chat_plugin(None)?;
    }
    Ok(state)
  }

  pub async fn get_local_llm_state(&self) -> FlowyResult<LocalModelResourcePB> {
    self.llm_res.get_local_llm_state()
  }

  pub fn get_current_model(&self) -> Option<LLMModel> {
    self.llm_res.get_selected_model()
  }

  pub async fn start_downloading<T>(&self, progress_sink: T) -> FlowyResult<String>
  where
    T: Sink<String, Error = anyhow::Error> + Unpin + Sync + Send + 'static,
  {
    let task_id = self.llm_res.start_downloading(progress_sink).await?;
    Ok(task_id)
  }

  pub fn cancel_download(&self) -> FlowyResult<()> {
    self.llm_res.cancel_download()?;
    Ok(())
  }

  pub fn get_chat_plugin_state(&self) -> LocalAIPluginStatePB {
    let state = self.llm_chat.get_plugin_running_state();
    LocalAIPluginStatePB {
      state: RunningStatePB::from(state),
    }
  }

  pub fn restart_chat_plugin(&self) {
    if let Ok(chat_config) = self.llm_res.get_ai_plugin_config() {
      if let Err(err) = initialize_chat_plugin(&self.llm_chat, chat_config) {
        error!("[AI Plugin] failed to setup plugin: {:?}", err);
      }
    }
  }

  pub async fn toggle_local_ai(&self) -> FlowyResult<bool> {
    let enabled = !self.store_preferences.get_bool(APPFLOWY_LOCAL_AI_ENABLED);
    self
      .store_preferences
      .set_bool(APPFLOWY_LOCAL_AI_ENABLED, enabled)?;

    // when enable local ai. we need to check if chat is enabled, if enabled, we need to init chat plugin
    // otherwise, we need to destroy the plugin
    if enabled {
      let chat_enabled = self
        .store_preferences
        .get_bool(APPFLOWY_LOCAL_AI_CHAT_ENABLED);
      self.enable_chat_plugin(chat_enabled).await?;
    } else {
      self.enable_chat_plugin(false).await?;
    }
    Ok(enabled)
  }

  pub async fn toggle_local_ai_chat(&self) -> FlowyResult<bool> {
    let enabled = !self
      .store_preferences
      .get_bool(APPFLOWY_LOCAL_AI_CHAT_ENABLED);
    self
      .store_preferences
      .set_bool(APPFLOWY_LOCAL_AI_CHAT_ENABLED, enabled)?;
    self.enable_chat_plugin(enabled).await?;
    Ok(enabled)
  }

  async fn enable_chat_plugin(&self, enabled: bool) -> FlowyResult<()> {
    if enabled {
      let (tx, rx) = tokio::sync::oneshot::channel();
      if let Err(err) = self.initialize_chat_plugin(Some(tx)) {
        error!("[AI Plugin] failed to initialize local ai: {:?}", err);
      }
      let _ = rx.await;
    } else {
      if let Err(err) = self.llm_chat.destroy_chat_plugin().await {
        error!("[AI Plugin] failed to destroy plugin: {:?}", err);
      }
    }
    Ok(())
  }
}

fn initialize_chat_plugin(
  llm_chat: &Arc<LocalChatLLMChat>,
  mut chat_config: AIPluginConfig,
) -> FlowyResult<()> {
  let llm_chat = llm_chat.clone();
  tokio::spawn(async move {
    trace!("[AI Plugin] config: {:?}", chat_config);
    if is_apple_silicon().await.unwrap_or(false) {
      chat_config = chat_config.with_device("gpu");
    }
    match llm_chat.init_chat_plugin(chat_config).await {
      Ok(_) => {
        send_notification(
          APPFLOWY_AI_NOTIFICATION_KEY,
          ChatNotification::UpdateChatPluginState,
        )
        .payload(ChatStatePB {
          model_type: ModelTypePB::LocalAI,
          available: true,
        });
      },
      Err(err) => {
        send_notification(
          APPFLOWY_AI_NOTIFICATION_KEY,
          ChatNotification::UpdateChatPluginState,
        )
        .payload(ChatStatePB {
          model_type: ModelTypePB::LocalAI,
          available: false,
        });
        error!("[AI Plugin] failed to setup plugin: {:?}", err);
      },
    }
  });
  Ok(())
}

pub struct LLMResourceServiceImpl {
  user_service: Arc<dyn ChatUserService>,
  cloud_service: Arc<dyn ChatCloudService>,
  store_preferences: Arc<KVStorePreferences>,
}
#[async_trait]
impl LLMResourceService for LLMResourceServiceImpl {
  async fn get_local_ai_config(&self) -> Result<LocalAIConfig, anyhow::Error> {
    let workspace_id = self.user_service.workspace_id()?;
    let config = self
      .cloud_service
      .get_local_ai_config(&workspace_id)
      .await?;
    Ok(config)
  }

  fn store(&self, setting: LLMSetting) -> Result<(), Error> {
    self
      .store_preferences
      .set_object(LOCAL_AI_SETTING_KEY, setting)?;
    Ok(())
  }

  fn retrieve(&self) -> Option<LLMSetting> {
    self
      .store_preferences
      .get_object::<LLMSetting>(LOCAL_AI_SETTING_KEY)
  }
}
