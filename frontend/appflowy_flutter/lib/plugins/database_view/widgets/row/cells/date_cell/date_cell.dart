import 'package:appflowy/plugins/database_view/application/cell/cell_controller_builder.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:appflowy_popover/appflowy_popover.dart';

import '../../../../grid/presentation/layout/sizes.dart';
import '../../cell_builder.dart';
import 'date_cell_bloc.dart';
import 'date_editor.dart';

class DateCellStyle extends GridCellStyle {
  Alignment alignment;

  DateCellStyle({this.alignment = Alignment.center});
}

abstract class GridCellDelegate {
  void onFocus(final bool isFocus);
  GridCellDelegate get delegate;
}

class GridDateCell extends GridCellWidget {
  final CellControllerBuilder cellControllerBuilder;
  late final DateCellStyle? cellStyle;

  GridDateCell({
    final GridCellStyle? style,
    required this.cellControllerBuilder,
    final Key? key,
  }) : super(key: key) {
    if (style != null) {
      cellStyle = (style as DateCellStyle);
    } else {
      cellStyle = null;
    }
  }

  @override
  GridCellState<GridDateCell> createState() => _DateCellState();
}

class _DateCellState extends GridCellState<GridDateCell> {
  late PopoverController _popover;
  late DateCellBloc _cellBloc;

  @override
  void initState() {
    _popover = PopoverController();
    final cellController =
        widget.cellControllerBuilder.build() as DateCellController;
    _cellBloc = DateCellBloc(cellController: cellController)
      ..add(const DateCellEvent.initial());
    super.initState();
  }

  @override
  Widget build(final BuildContext context) {
    final alignment = widget.cellStyle != null
        ? widget.cellStyle!.alignment
        : Alignment.centerLeft;
    return BlocProvider.value(
      value: _cellBloc,
      child: BlocBuilder<DateCellBloc, DateCellState>(
        builder: (final context, final state) {
          return AppFlowyPopover(
            controller: _popover,
            triggerActions: PopoverTriggerFlags.none,
            direction: PopoverDirection.bottomWithLeftAligned,
            constraints: BoxConstraints.loose(const Size(260, 500)),
            margin: EdgeInsets.zero,
            child: SizedBox.expand(
              child: Align(
                alignment: alignment,
                child: Padding(
                  padding: GridSize.cellContentInsets,
                  child: FlowyText.medium(
                    state.dateStr,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            popupBuilder: (final BuildContext popoverContent) {
              return DateCellEditor(
                cellController:
                    widget.cellControllerBuilder.build() as DateCellController,
                onDismissed: () => widget.onCellEditing.value = false,
              );
            },
            onClose: () {
              widget.onCellEditing.value = false;
            },
          );
        },
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _cellBloc.close();
    super.dispose();
  }

  @override
  void requestBeginFocus() {
    _popover.show();
    widget.onCellEditing.value = true;
  }

  @override
  String? onCopy() => _cellBloc.state.dateStr;
}
