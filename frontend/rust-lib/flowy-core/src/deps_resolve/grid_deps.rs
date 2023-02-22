use crate::FlowyError;
use bytes::Bytes;
use flowy_client_ws::FlowyWebSocketConnect;
use flowy_database::manager::{DatabaseManager, DatabaseUser};
use flowy_database::services::persistence::DatabaseDB;
use flowy_revision::{RevisionWebSocket, WSStateReceiver};
use flowy_sqlite::ConnectionPool;
use flowy_task::TaskDispatcher;
use flowy_user::services::UserSession;
use futures_core::future::BoxFuture;
use lib_infra::future::BoxResultFuture;
use lib_ws::{WSChannel, WebSocketRawMessage};
use std::convert::TryInto;
use std::sync::Arc;
use tokio::sync::RwLock;
use ws_model::ws_revision::ClientRevisionWSData;

pub struct GridDepsResolver();

impl GridDepsResolver {
  pub async fn resolve(
    ws_conn: Arc<FlowyWebSocketConnect>,
    user_session: Arc<UserSession>,
    task_scheduler: Arc<RwLock<TaskDispatcher>>,
  ) -> Arc<DatabaseManager> {
    let user = Arc::new(GridUserImpl(user_session.clone()));
    let rev_web_socket = Arc::new(GridRevisionWebSocket(ws_conn));
    let grid_manager = Arc::new(DatabaseManager::new(
      user.clone(),
      rev_web_socket,
      task_scheduler,
      Arc::new(GridDatabaseImpl(user_session)),
    ));

    if let (Ok(user_id), Ok(token)) = (user.user_id(), user.token()) {
      match grid_manager.initialize(&user_id, &token).await {
        Ok(_) => {},
        Err(e) => tracing::error!("Initialize grid manager failed: {}", e),
      }
    }

    grid_manager
  }
}

struct GridDatabaseImpl(Arc<UserSession>);
impl DatabaseDB for GridDatabaseImpl {
  fn db_pool(&self) -> Result<Arc<ConnectionPool>, FlowyError> {
    self
      .0
      .db_pool()
      .map_err(|e| FlowyError::internal().context(e))
  }
}

struct GridUserImpl(Arc<UserSession>);
impl DatabaseUser for GridUserImpl {
  fn user_id(&self) -> Result<String, FlowyError> {
    self.0.user_id()
  }

  fn token(&self) -> Result<String, FlowyError> {
    self.0.token()
  }

  fn db_pool(&self) -> Result<Arc<ConnectionPool>, FlowyError> {
    self.0.db_pool()
  }
}

struct GridRevisionWebSocket(Arc<FlowyWebSocketConnect>);
impl RevisionWebSocket for GridRevisionWebSocket {
  fn send(&self, data: ClientRevisionWSData) -> BoxResultFuture<(), FlowyError> {
    let bytes: Bytes = data.try_into().unwrap();
    let msg = WebSocketRawMessage {
      channel: WSChannel::Database,
      data: bytes.to_vec(),
    };

    let ws_conn = self.0.clone();
    Box::pin(async move {
      match ws_conn.web_socket().await? {
        None => {},
        Some(sender) => {
          sender
            .send(msg)
            .map_err(|e| FlowyError::internal().context(e))?;
        },
      }
      Ok(())
    })
  }

  fn subscribe_state_changed(&self) -> BoxFuture<WSStateReceiver> {
    let ws_conn = self.0.clone();
    Box::pin(async move { ws_conn.subscribe_websocket_state().await })
  }
}
