import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/widgets/cell/editable_cell_skeleton/date.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/cell_container.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/date_cell/date_cell_bloc.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/date_cell/date_editor.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

class DesktopRowDetailDateCellSkin extends IEditableDateCellSkin {
  @override
  Widget build(
    BuildContext context,
    CellContainerNotifier cellContainerNotifier,
    DateCellBloc bloc,
    DateCellState state,
    PopoverController popoverController,
  ) {
    final text = state.dateStr.isEmpty
        ? LocaleKeys.grid_row_textPlaceholder.tr()
        : state.dateStr;
    final color = state.dateStr.isEmpty ? Theme.of(context).hintColor : null;

    return AppFlowyPopover(
      controller: popoverController,
      triggerActions: PopoverTriggerFlags.none,
      direction: PopoverDirection.bottomWithLeftAligned,
      constraints: BoxConstraints.loose(const Size(260, 620)),
      margin: EdgeInsets.zero,
      child: Container(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: FlowyText.medium(
          text,
          color: color,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      popupBuilder: (BuildContext popoverContent) {
        return DateCellEditor(
          cellController: bloc.cellController,
          onDismissed: () => cellContainerNotifier.isFocus = false,
        );
      },
      onClose: () {
        cellContainerNotifier.isFocus = false;
      },
    );
  }
}
