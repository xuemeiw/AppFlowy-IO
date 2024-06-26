use crate::error::{Error, ReadError, RemoteError};
use crate::parser::ResponseParser;
use crate::plugin::{start_plugin_process, Plugin, PluginId, PluginInfo, RpcCtx};
use crate::rpc_loop::Handler;
use crate::rpc_peer::PluginCommand;
use anyhow::anyhow;
use lib_infra::util::{get_operating_system, OperatingSystem};
use parking_lot::Mutex;
use serde_json::{json, Value};
use std::io;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Arc, Weak};
use tracing::{trace, warn};

pub struct SidecarManager {
  state: Arc<Mutex<SidecarState>>,
  plugin_id_counter: Arc<AtomicI64>,
  operating_system: OperatingSystem,
}

impl SidecarManager {
  pub fn new() -> Self {
    SidecarManager {
      state: Arc::new(Mutex::new(SidecarState {
        plugins: Vec::new(),
      })),
      plugin_id_counter: Arc::new(Default::default()),
      operating_system: get_operating_system(),
    }
  }

  pub async fn create_plugin(&self, plugin_info: PluginInfo) -> Result<PluginId, Error> {
    if self.operating_system.is_not_desktop() {
      return Err(Error::Internal(anyhow!(
        "plugin not supported on this platform"
      )));
    }
    let plugin_id = PluginId::from(self.plugin_id_counter.fetch_add(1, Ordering::SeqCst));
    let weak_state = WeakSidecarState(Arc::downgrade(&self.state));
    start_plugin_process(plugin_info, plugin_id, weak_state).await?;
    Ok(plugin_id)
  }

  pub async fn remove_plugin(&self, id: PluginId) -> Result<(), Error> {
    if self.operating_system.is_not_desktop() {
      return Err(Error::Internal(anyhow!(
        "plugin not supported on this platform"
      )));
    }

    let state = self.state.lock();
    let plugin = state
      .plugins
      .iter()
      .find(|p| p.id == id)
      .ok_or(anyhow!("plugin not found"))?;
    plugin.shutdown();
    Ok(())
  }

  pub fn init_plugin(&self, id: PluginId, init_params: Value) -> Result<(), Error> {
    if self.operating_system.is_not_desktop() {
      return Err(Error::Internal(anyhow!(
        "plugin not supported on this platform"
      )));
    }

    let state = self.state.lock();
    let plugin = state
      .plugins
      .iter()
      .find(|p| p.id == id)
      .ok_or(anyhow!("plugin not found"))?;
    plugin.initialize(init_params)?;

    Ok(())
  }

  pub fn send_request<P: ResponseParser>(
    &self,
    id: PluginId,
    method: &str,
    request: Value,
  ) -> Result<P::ValueType, Error> {
    let state = self.state.lock();
    let plugin = state
      .plugins
      .iter()
      .find(|p| p.id == id)
      .ok_or(anyhow!("plugin not found"))?;
    let resp = plugin.send_request(method, &request)?;
    let value = P::parse_response(resp)?;
    Ok(value)
  }

  pub async fn async_send_request<P: ResponseParser>(
    &self,
    id: PluginId,
    method: &str,
    request: Value,
  ) -> Result<P::ValueType, Error> {
    let state = self.state.lock();
    let plugin = state
      .plugins
      .iter()
      .find(|p| p.id == id)
      .ok_or(anyhow!("plugin not found"))?;
    let resp = plugin.async_send_request(method, &request).await?;
    let value = P::parse_response(resp)?;
    Ok(value)
  }
}

pub struct SidecarState {
  plugins: Vec<Plugin>,
}

impl SidecarState {
  pub fn plugin_connect(&mut self, plugin: Result<Plugin, io::Error>) {
    match plugin {
      Ok(plugin) => {
        trace!("plugin connected: {:?}", plugin.id);
        self.plugins.push(plugin);
      },
      Err(err) => {
        warn!("plugin failed to connect: {:?}", err);
      },
    }
  }

  pub fn plugin_disconnect(&mut self, id: PluginId, error: Result<(), ReadError>) {
    if let Err(err) = error {
      warn!("[RPC] plugin {:?} exited with result {:?}", id, err);
    }
    let running_idx = self.plugins.iter().position(|p| p.id == id);
    if let Some(idx) = running_idx {
      let plugin = self.plugins.remove(idx);
      plugin.shutdown();
    }
  }
}

#[derive(Clone)]
pub struct WeakSidecarState(Weak<Mutex<SidecarState>>);

impl WeakSidecarState {
  pub fn upgrade(&self) -> Option<Arc<Mutex<SidecarState>>> {
    self.0.upgrade()
  }

  pub fn plugin_connect(&self, plugin: Result<Plugin, io::Error>) {
    if let Some(state) = self.upgrade() {
      state.lock().plugin_connect(plugin)
    }
  }

  pub fn plugin_exit(&self, plugin: PluginId, error: Result<(), ReadError>) {
    if let Some(core) = self.upgrade() {
      core.lock().plugin_disconnect(plugin, error)
    }
  }
}

impl Handler for WeakSidecarState {
  type Request = PluginCommand<String>;

  fn handle_request(&mut self, _ctx: &RpcCtx, rpc: Self::Request) -> Result<Value, RemoteError> {
    trace!("handling request: {:?}", rpc.cmd);
    Ok(json!({}))
  }
}
