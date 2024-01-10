import 'package:appflowy/plugins/database/application/cell/cell_controller_builder.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/cell_container.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/text_cell/text_cell_bloc.dart';
import 'package:appflowy/plugins/database/widgets/cell/editable_cell_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../desktop_grid/desktop_grid_text_cell.dart';
import '../desktop_row_detail/desktop_row_detail_text_cell.dart';
import '../mobile_grid/mobile_grid_text_cell.dart';
import '../mobile_row_detail/mobile_row_detail_text_cell.dart';

abstract class IEditableTextCellSkin {
  const IEditableTextCellSkin();

  Widget build(
    BuildContext context,
    CellContainerNotifier cellContainerNotifier,
    TextCellBloc bloc,
    FocusNode focusNode,
    TextEditingController textEditingController,
  );

  factory IEditableTextCellSkin.fromStyle(EditableCellStyle style) {
    return switch (style) {
      EditableCellStyle.desktopGrid => DesktopGridTextCellSkin(),
      EditableCellStyle.desktopRowDetail => DesktopRowDetailTextCellSkin(),
      EditableCellStyle.mobileGrid => MobileGridTextCellSkin(),
      EditableCellStyle.mobileRowDetail => MobileRowDetailTextCellSkin(),
    };
  }
}

class EditableTextCell extends EditableCellWidget {
  final TextCellController cellController;
  final IEditableTextCellSkin skin;

  EditableTextCell({
    required this.cellController,
    required this.skin,
    super.key,
  });

  @override
  GridEditableTextCell<EditableTextCell> createState() => _TextCellState();
}

class _TextCellState extends GridEditableTextCell<EditableTextCell> {
  late final TextEditingController _textEditingController;
  late final cellBloc = TextCellBloc(cellController: widget.cellController)
    ..add(const TextCellEvent.initial());

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController();
  }

  @override
  Future<void> dispose() async {
    _textEditingController.dispose();
    cellBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cellBloc,
      child: BlocListener<TextCellBloc, TextCellState>(
        listener: (context, state) {
          _textEditingController.text = state.content;
        },
        child: widget.skin.build(
          context,
          widget.cellContainerNotifier,
          cellBloc,
          focusNode,
          _textEditingController,
        ),
      ),
    );
  }

  @override
  SingleListenerFocusNode focusNode = SingleListenerFocusNode();

  @override
  void requestBeginFocus() {
    focusNode.requestFocus(); //TODO YAY
  }

  @override
  String? onCopy() => cellBloc.state.content;

  @override
  Future<void> focusChanged() {
    if (mounted && !cellBloc.isClosed) {
      cellBloc.add(
        TextCellEvent.updateText(_textEditingController.text),
      );
    }
    return super.focusChanged();
  }
}
