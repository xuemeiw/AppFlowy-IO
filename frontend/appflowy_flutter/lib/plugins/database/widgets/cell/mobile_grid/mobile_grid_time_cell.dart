import 'package:flutter/material.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/cell_container.dart';
import 'package:appflowy/plugins/database/application/cell/bloc/time_cell_bloc.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';

import '../editable_cell_skeleton/time.dart';

class MobileGridTimeCellSkin extends IEditableTimeCellSkin {
  @override
  Widget build(
    BuildContext context,
    CellContainerNotifier cellContainerNotifier,
    TimeCellBloc bloc,
    FocusNode focusNode,
    TextEditingController textEditingController,
    PopoverController popoverController,
  ) {
    final timeCellState = bloc.state;

    return TextField(
      controller: textEditingController,
      focusNode: focusNode,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15),
      decoration: const InputDecoration(
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isCollapsed: true,
      ),
      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
      readOnly: timeCellState.timeType != TimeTypePB.PlainTime,
    );
  }
}
