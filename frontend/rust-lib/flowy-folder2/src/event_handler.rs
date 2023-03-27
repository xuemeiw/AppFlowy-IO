use crate::entities::{
  CreateViewParams, CreateViewPayloadPB, CreateWorkspaceParams, CreateWorkspacePayloadPB,
  MoveFolderItemParams, MoveFolderItemPayloadPB, RepeatedTrashIdPB, RepeatedTrashPB,
  RepeatedViewIdPB, RepeatedViewPB, RepeatedWorkspacePB, TrashIdPB, UpdateViewParams,
  UpdateViewPayloadPB, ViewIdPB, ViewPB, WorkspaceIdPB, WorkspacePB, WorkspaceSettingPB,
};
use crate::manager::Folder2Manager;
use collab_folder::core::View;
use flowy_error::FlowyError;
use lib_dispatch::prelude::{data_result_ok, AFPluginData, AFPluginState, DataResult};
use std::sync::Arc;

#[tracing::instrument(level = "debug", skip(data, folder), err)]
pub(crate) async fn create_workspace_handler(
  data: AFPluginData<CreateWorkspacePayloadPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> DataResult<WorkspacePB, FlowyError> {
  let params: CreateWorkspaceParams = data.into_inner().try_into()?;
  let workspace = folder.create_workspace(params).await?;
  data_result_ok(workspace.into())
}

#[tracing::instrument(level = "debug", skip(folder), err)]
pub(crate) async fn read_workspace_apps_handler(
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> DataResult<RepeatedViewPB, FlowyError> {
  let child_views = folder.get_current_workspace_views().await?;
  let repeated_view: RepeatedViewPB = child_views.into();
  data_result_ok(repeated_view)
}

#[tracing::instrument(level = "debug", skip(data, folder), err)]
pub(crate) async fn open_workspace_handler(
  data: AFPluginData<WorkspaceIdPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> DataResult<WorkspacePB, FlowyError> {
  let params: WorkspaceIdPB = data.into_inner();
  match params.value {
    None => Err(FlowyError::workspace_id().context("workspace id should not be empty")),
    Some(workspace_id) => {
      let workspace = folder.open_workspace(&workspace_id).await?;
      let workspace_pb: WorkspacePB = workspace.into();
      data_result_ok(workspace_pb)
    },
  }
}

#[tracing::instrument(level = "debug", skip(data, folder), err)]
pub(crate) async fn read_workspaces_handler(
  data: AFPluginData<WorkspaceIdPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> DataResult<RepeatedWorkspacePB, FlowyError> {
  let params: WorkspaceIdPB = data.into_inner();
  let workspaces = match params.value {
    None => folder.get_all_workspaces().await,
    Some(workspace_id) => folder
      .get_workspace(&workspace_id)
      .await
      .map(|workspace| vec![workspace])
      .unwrap_or_default(),
  };

  data_result_ok(workspaces.into())
}

#[tracing::instrument(level = "debug", skip(folder), err)]
pub async fn read_cur_workspace_setting_handler(
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> DataResult<WorkspaceSettingPB, FlowyError> {
  let workspace: WorkspacePB = folder.get_current_workspace().await?.into();
  let latest_view: Option<ViewPB> = match folder.get_current_view().await {
    None => None,
    Some(view) => Some(view_pb_from_view(view, &folder).await),
  };
  data_result_ok(WorkspaceSettingPB {
    workspace,
    latest_view,
  })
}

async fn view_pb_from_view(view: View, folder: &Arc<Folder2Manager>) -> ViewPB {
  let mut view_pb: ViewPB = view.into();
  if let Ok(child_views) = folder.get_views_belong_to(&view_pb.id).await {
    view_pb.belongings = child_views
      .into_iter()
      .map(|view| view.into())
      .collect::<Vec<ViewPB>>();
  }
  view_pb
}

pub(crate) async fn create_view_handler(
  data: AFPluginData<CreateViewPayloadPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> DataResult<ViewPB, FlowyError> {
  let params: CreateViewParams = data.into_inner().try_into()?;
  let view = folder.create_view_with_params(params).await?;
  data_result_ok(view.into())
}

pub(crate) async fn read_view_handler(
  data: AFPluginData<ViewIdPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> DataResult<ViewPB, FlowyError> {
  let view_id: ViewIdPB = data.into_inner();
  let view = folder.get_view(&view_id.value).await?;
  let view_pb = view_pb_from_view(view, &folder).await;
  data_result_ok(view_pb)
}

#[tracing::instrument(level = "debug", skip(data, folder), err)]
pub(crate) async fn update_view_handler(
  data: AFPluginData<UpdateViewPayloadPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> Result<(), FlowyError> {
  let params: UpdateViewParams = data.into_inner().try_into()?;
  let _ = folder.update_view_with_params(params).await?;
  Ok(())
}

pub(crate) async fn delete_view_handler(
  data: AFPluginData<RepeatedViewIdPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> Result<(), FlowyError> {
  let params: RepeatedViewIdPB = data.into_inner();
  for view_id in &params.items {
    let _ = folder.move_view_to_trash(view_id).await;
  }
  Ok(())
}

#[tracing::instrument(level = "debug", skip(data, folder), err)]
pub(crate) async fn set_latest_view_handler(
  data: AFPluginData<ViewIdPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> Result<(), FlowyError> {
  let view_id: ViewIdPB = data.into_inner();
  let _ = folder.set_current_view(&view_id.value).await;
  Ok(())
}

pub(crate) async fn close_view_handler(
  data: AFPluginData<ViewIdPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> Result<(), FlowyError> {
  let view_id: ViewIdPB = data.into_inner();
  let _ = folder.close_view(&view_id.value).await;
  Ok(())
}

#[tracing::instrument(level = "debug", skip_all, err)]
pub(crate) async fn move_item_handler(
  data: AFPluginData<MoveFolderItemPayloadPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> Result<(), FlowyError> {
  let params: MoveFolderItemParams = data.into_inner().try_into()?;
  folder
    .move_view(&params.item_id, params.from, params.to)
    .await?;
  Ok(())
}

#[tracing::instrument(level = "debug", skip(data, folder), err)]
pub(crate) async fn duplicate_view_handler(
  data: AFPluginData<ViewPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> Result<(), FlowyError> {
  let view: ViewPB = data.into_inner();
  folder.duplicate_view(&view.id).await?;
  Ok(())
}

#[tracing::instrument(level = "debug", skip(folder), err)]
pub(crate) async fn read_trash_handler(
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> DataResult<RepeatedTrashPB, FlowyError> {
  let trash = folder.get_all_trash().await;
  data_result_ok(trash.into())
}

#[tracing::instrument(level = "debug", skip(identifier, folder), err)]
pub(crate) async fn putback_trash_handler(
  identifier: AFPluginData<TrashIdPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> Result<(), FlowyError> {
  folder.restore_trash(&identifier.id).await;
  Ok(())
}

#[tracing::instrument(level = "debug", skip(identifiers, folder), err)]
pub(crate) async fn delete_trash_handler(
  identifiers: AFPluginData<RepeatedTrashIdPB>,
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> Result<(), FlowyError> {
  let trash_ids = identifiers.into_inner().items;
  for trash_id in trash_ids {
    folder.delete_trash(&trash_id.id).await;
  }
  Ok(())
}

#[tracing::instrument(level = "debug", skip(folder), err)]
pub(crate) async fn restore_all_trash_handler(
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> Result<(), FlowyError> {
  folder.restore_all_trash().await;
  Ok(())
}

#[tracing::instrument(level = "debug", skip(folder), err)]
pub(crate) async fn delete_all_trash_handler(
  folder: AFPluginState<Arc<Folder2Manager>>,
) -> Result<(), FlowyError> {
  folder.delete_all_trash().await;
  Ok(())
}
