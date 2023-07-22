use appflowy_integrate::CollabType;
use chrono::{DateTime, Utc};
use collab_folder::core::{CollabOrigin, Folder};
use futures_util::{pin_mut, StreamExt};
use tokio::sync::oneshot::channel;
use uuid::Uuid;

use flowy_error::{internal_error, ErrorCode, FlowyError, FlowyResult};
use flowy_folder2::deps::{FolderCloudService, FolderData, FolderSnapshot, Workspace};
use lib_infra::future::FutureResult;

use crate::supabase::impls::util::try_upgrade_server;
use crate::supabase::impls::{
  get_latest_snapshot_from_server, get_updates_from_server, FetchObjectUpdateAction,
};
use crate::supabase::postgres_db::{prepare_cached, PostgresObject};
use crate::supabase::sql_builder::{InsertSqlBuilder, SelectSqlBuilder};
use crate::supabase::{PgConnectMode, SupabaseServerService};

pub(crate) const WORKSPACE_TABLE: &str = "af_workspace";
pub(crate) const LATEST_WORKSPACE_ID: &str = "latest_workspace_id";
const WORKSPACE_NAME: &str = "workspace_name";
const CREATED_AT: &str = "created_at";

pub struct SupabaseFolderCloudServiceImpl<T> {
  server: T,
}

impl<T> SupabaseFolderCloudServiceImpl<T> {
  pub fn new(server: T) -> Self {
    Self { server }
  }
}

impl<T> FolderCloudService for SupabaseFolderCloudServiceImpl<T>
where
  T: SupabaseServerService,
{
  fn create_workspace(&self, uid: i64, name: &str) -> FutureResult<Workspace, FlowyError> {
    let pg_mode = self.server.get_pg_mode();
    let weak_server = self.server.try_get_pg_server();
    let (tx, rx) = channel();
    let name = name.to_string();
    tokio::spawn(async move {
      tx.send(
        async move {
          let server = try_upgrade_server(weak_server)?;
          let client = server.get_pg_client().await.recv().await?;
          create_workspace(&client, &pg_mode, uid, &name).await
        }
        .await,
      )
    });
    FutureResult::new(async { rx.await.map_err(internal_error)? })
  }

  fn add_member_to_workspace(
    &self,
    email: &str,
    workspace_id: &str,
  ) -> FutureResult<(), FlowyError> {
    let pg_mode = self.server.get_pg_mode();
    let weak_server = self.server.try_get_pg_server();
    let email = email.to_string();
    let workspace_id = workspace_id.to_string();
    let (tx, rx) = channel();
    tokio::spawn(async move {
      tx.send(
        async move {
          let server = try_upgrade_server(weak_server)?;
          let client = server.get_pg_client().await.recv().await?;
          add_member_to_workspace(&client, &pg_mode, &email, &workspace_id).await
        }
        .await,
      )
    });
    FutureResult::new(async { rx.await.map_err(internal_error)? })
  }

  fn remove_member_from_workspace(
    &self,
    _email: &str,
    _workspace_id: &str,
  ) -> FutureResult<(), FlowyError> {
    todo!()
  }

  fn get_folder_data(&self, workspace_id: &str) -> FutureResult<Option<FolderData>, FlowyError> {
    let weak_server = self.server.get_pg_server();
    let pg_mode = self.server.get_pg_mode();
    let (tx, rx) = channel();
    let workspace_id = workspace_id.to_string();
    tokio::spawn(async move {
      tx.send(
        async move {
          match weak_server {
            None => Ok(Ok(None)),
            Some(weak_server) => get_updates_from_server(&workspace_id, &pg_mode, weak_server)
              .await
              .map(|updates| {
                let folder = Folder::from_collab_raw_data(
                  CollabOrigin::Empty,
                  updates,
                  &workspace_id,
                  vec![],
                )?;
                Ok(folder.get_folder_data())
              }),
          }
        }
        .await,
      )
    });
    FutureResult::new(async { rx.await.map_err(internal_error)?.map_err(internal_error)? })
  }

  fn get_folder_latest_snapshot(
    &self,
    workspace_id: &str,
  ) -> FutureResult<Option<FolderSnapshot>, FlowyError> {
    let weak_server = self.server.get_pg_server();
    let pg_mode = self.server.get_pg_mode();
    let workspace_id = workspace_id.to_string();
    let (tx, rx) = channel();
    tokio::spawn(async move {
      tx.send(
        async {
          match weak_server {
            None => Ok(None),
            Some(weak_server) => {
              get_latest_snapshot_from_server(&workspace_id, pg_mode, weak_server)
                .await
                .map_err(internal_error)
            },
          }
        }
        .await,
      )
    });
    FutureResult::new(async {
      Ok(
        rx.await
          .map_err(internal_error)??
          .map(|snapshot| FolderSnapshot {
            snapshot_id: snapshot.snapshot_id,
            database_id: snapshot.oid,
            data: snapshot.data,
            created_at: snapshot.created_at,
          }),
      )
    })
  }

  fn get_folder_updates(
    &self,
    workspace_id: &str,
    _uid: i64,
  ) -> FutureResult<Vec<Vec<u8>>, FlowyError> {
    let weak_server = self.server.get_pg_server();
    let pg_mode = self.server.get_pg_mode();
    let (tx, rx) = channel();
    let workspace_id = workspace_id.to_string();
    tokio::spawn(async move {
      tx.send(
        async move {
          match weak_server {
            None => Ok(vec![]),
            Some(weak_server) => {
              let action = FetchObjectUpdateAction::new(
                workspace_id,
                CollabType::Folder,
                pg_mode,
                weak_server,
              );
              action.run_with_fix_interval(5, 10).await
            },
          }
        }
        .await,
      )
    });
    FutureResult::new(async { rx.await.map_err(internal_error)?.map_err(internal_error) })
  }

  fn service_name(&self) -> String {
    "Supabase".to_string()
  }
}

async fn add_member_to_workspace(
  _client: &PostgresObject,
  _pg_mode: &PgConnectMode,
  _email: &str,
  _workspace_id: &str,
) -> FlowyResult<()> {
  Ok(())
}

async fn create_workspace(
  client: &PostgresObject,
  pg_mode: &PgConnectMode,
  uid: i64,
  name: &str,
) -> Result<Workspace, FlowyError> {
  let new_workspace_id = Uuid::new_v4();

  // Create workspace
  let (sql, params) = InsertSqlBuilder::new(WORKSPACE_TABLE)
    .value("uid", uid)
    .value(LATEST_WORKSPACE_ID, new_workspace_id)
    .value(WORKSPACE_NAME, name.to_string())
    .build();
  let stmt = prepare_cached(pg_mode, sql, client)
    .await
    .map_err(|e| FlowyError::new(ErrorCode::PgDatabaseError, e))?;
  client
    .execute_raw(stmt.as_ref(), params)
    .await
    .map_err(|e| FlowyError::new(ErrorCode::PgDatabaseError, e))?;

  // Read the workspace
  let (sql, params) = SelectSqlBuilder::new(WORKSPACE_TABLE)
    .column(LATEST_WORKSPACE_ID)
    .column(WORKSPACE_NAME)
    .column(CREATED_AT)
    .where_clause(LATEST_WORKSPACE_ID, new_workspace_id)
    .build();
  let stmt = prepare_cached(pg_mode, sql, client)
    .await
    .map_err(|e| FlowyError::new(ErrorCode::PgDatabaseError, e))?;

  let rows = Box::pin(
    client
      .query_raw(stmt.as_ref(), params)
      .await
      .map_err(|e| FlowyError::new(ErrorCode::PgDatabaseError, e))?,
  );
  pin_mut!(rows);

  if let Some(Ok(row)) = rows.next().await {
    let created_at = row
      .try_get::<&str, DateTime<Utc>>(CREATED_AT)
      .unwrap_or_default();
    let workspace_id: Uuid = row.get(LATEST_WORKSPACE_ID);

    Ok(Workspace {
      id: workspace_id.to_string(),
      name: row.get(WORKSPACE_NAME),
      child_views: Default::default(),
      created_at: created_at.timestamp(),
    })
  } else {
    Err(FlowyError::new(
      ErrorCode::PgDatabaseError,
      "Create workspace failed",
    ))
  }
}

#[cfg(test)]
mod tests {
  use std::collections::HashMap;
  use std::sync::Arc;

  use parking_lot::RwLock;
  use uuid::Uuid;

  use flowy_folder2::deps::FolderCloudService;
  use flowy_server_config::supabase_config::PostgresConfiguration;
  use flowy_user::event_map::UserService;
  use lib_infra::box_any::BoxAny;

  use crate::supabase::impls::folder::SupabaseFolderCloudServiceImpl;
  use crate::supabase::impls::SupabaseUserAuthServiceImpl;
  use crate::supabase::{PgConnectMode, PostgresServer, SupabaseServerServiceImpl};

  #[tokio::test]
  async fn create_user_workspace() {
    if dotenv::from_filename("./.env.workspace.test").is_err() {
      return;
    }
    let server = Arc::new(PostgresServer::new(
      PgConnectMode::default(),
      PostgresConfiguration::from_env().unwrap(),
    ));
    let weak_server = SupabaseServerServiceImpl(Arc::new(RwLock::new(Some(server.clone()))));
    let user_service = SupabaseUserAuthServiceImpl::new(weak_server.clone());

    // create user
    let mut params = HashMap::new();
    params.insert("uuid".to_string(), Uuid::new_v4().to_string());
    let user = user_service.sign_up(BoxAny::new(params)).await.unwrap();

    // create workspace
    let folder_service = SupabaseFolderCloudServiceImpl::new(weak_server);
    let workspace = folder_service
      .create_workspace(user.user_id, "my test workspace")
      .await
      .unwrap();

    assert_eq!(workspace.name, "my test workspace");
  }
}
