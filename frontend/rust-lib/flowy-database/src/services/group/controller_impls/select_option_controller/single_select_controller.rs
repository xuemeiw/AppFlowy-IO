use crate::entities::{GroupRowsNotificationPB, RowPB};
use crate::services::cell::insert_select_option_cell;
use crate::services::field::{
  SelectOptionCellDataPB, SelectOptionCellDataParser, SingleSelectTypeOptionPB,
};
use crate::services::group::action::GroupCustomize;

use crate::services::group::controller::{
  GenericGroupController, GroupController, GroupGenerator, MoveGroupRowContext,
};
use crate::services::group::controller_impls::select_option_controller::util::*;
use crate::services::group::entities::Group;

use crate::services::group::{make_no_status_group, GeneratedGroupContext};
use database_model::{FieldRevision, RowRevision, SelectOptionGroupConfigurationRevision};

// SingleSelect
pub type SingleSelectGroupController = GenericGroupController<
  SelectOptionGroupConfigurationRevision,
  SingleSelectTypeOptionPB,
  SingleSelectGroupGenerator,
  SelectOptionCellDataParser,
>;

impl GroupCustomize for SingleSelectGroupController {
  type CellData = SelectOptionCellDataPB;
  fn can_group(&self, content: &str, cell_data: &SelectOptionCellDataPB) -> bool {
    cell_data
      .select_options
      .iter()
      .any(|option| option.id == content)
  }

  fn add_or_remove_row_when_cell_changed(
    &mut self,
    row_rev: &RowRevision,
    cell_data: &Self::CellData,
  ) -> Vec<GroupRowsNotificationPB> {
    let mut changesets = vec![];
    self.group_ctx.iter_mut_status_groups(|group| {
      if let Some(changeset) = add_or_remove_select_option_row(group, cell_data, row_rev) {
        changesets.push(changeset);
      }
    });
    changesets
  }

  fn delete_row(
    &mut self,
    row_rev: &RowRevision,
    cell_data: &Self::CellData,
  ) -> Vec<GroupRowsNotificationPB> {
    let mut changesets = vec![];
    self.group_ctx.iter_mut_status_groups(|group| {
      if let Some(changeset) = remove_select_option_row(group, cell_data, row_rev) {
        changesets.push(changeset);
      }
    });
    changesets
  }

  fn move_row(
    &mut self,
    _cell_data: &Self::CellData,
    mut context: MoveGroupRowContext,
  ) -> Vec<GroupRowsNotificationPB> {
    let mut group_changeset = vec![];
    self.group_ctx.iter_mut_groups(|group| {
      if let Some(changeset) = move_group_row(group, &mut context) {
        group_changeset.push(changeset);
      }
    });
    group_changeset
  }
}

impl GroupController for SingleSelectGroupController {
  fn will_create_row(
    &mut self,
    row_rev: &mut RowRevision,
    field_rev: &FieldRevision,
    group_id: &str,
  ) {
    let group: Option<&mut Group> = self.group_ctx.get_mut_group(group_id);
    match group {
      None => {},
      Some(group) => {
        let cell_rev = insert_select_option_cell(vec![group.id.clone()], field_rev);
        row_rev.cells.insert(field_rev.id.clone(), cell_rev);
      },
    }
  }
  fn did_create_row(&mut self, row_pb: &RowPB, group_id: &str) {
    if let Some(group) = self.group_ctx.get_mut_group(group_id) {
      group.add_row(row_pb.clone())
    }
  }
}

pub struct SingleSelectGroupGenerator();
impl GroupGenerator for SingleSelectGroupGenerator {
  type Context = SelectOptionGroupContext;
  type TypeOptionType = SingleSelectTypeOptionPB;
  fn generate_groups(
    field_rev: &FieldRevision,
    group_ctx: &Self::Context,
    type_option: &Option<Self::TypeOptionType>,
  ) -> GeneratedGroupContext {
    let group_configs = match type_option {
      None => vec![],
      Some(type_option) => {
        generate_select_option_groups(&field_rev.id, group_ctx, &type_option.options)
      },
    };

    GeneratedGroupContext {
      no_status_group: Some(make_no_status_group(field_rev)),
      group_configs,
    }
  }
}
