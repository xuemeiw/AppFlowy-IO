import 'dart:collection';
import 'package:app_flowy/plugins/grid/application/block/block_cache.dart';
import 'package:app_flowy/plugins/grid/application/cell/cell_service/cell_service.dart';
import 'package:app_flowy/plugins/grid/application/field/field_controller.dart';
import 'package:app_flowy/plugins/grid/application/field/field_editor_bloc.dart';
import 'package:app_flowy/plugins/grid/application/field/field_service.dart';
import 'package:app_flowy/plugins/grid/application/field/type_option/type_option_context.dart';
import 'package:app_flowy/plugins/grid/application/grid_data_controller.dart';
import 'package:app_flowy/plugins/grid/application/row/row_bloc.dart';
import 'package:app_flowy/plugins/grid/application/row/row_cache.dart';
import 'package:app_flowy/plugins/grid/application/row/row_data_controller.dart';
import 'package:app_flowy/plugins/grid/grid.dart';
import 'package:app_flowy/workspace/application/app/app_service.dart';
import 'package:flowy_sdk/protobuf/flowy-folder/view.pb.dart';
import 'package:flowy_sdk/protobuf/flowy-grid/field_entities.pb.dart';

import '../../util.dart';

class GridTestContext {
  final ViewPB gridView;
  final GridController _gridController;

  GridTestContext(this.gridView, this._gridController);

  List<RowInfo> get rowInfos {
    return _gridController.rowInfos;
  }

  UnmodifiableMapView<String, GridBlockCache> get blocks {
    return _gridController.blocks;
  }

  List<GridFieldInfo> get fieldContexts => fieldController.fieldInfos;

  GridFieldController get fieldController {
    return _gridController.fieldController;
  }

  Future<void> createRow() async {
    return _gridController.createRow();
  }

  FieldEditorBloc createFieldEditor({
    GridFieldInfo? fieldInfo,
  }) {
    IFieldTypeOptionLoader loader;
    if (fieldInfo == null) {
      loader = NewFieldTypeOptionLoader(gridId: gridView.id);
    } else {
      loader =
          FieldTypeOptionLoader(gridId: gridView.id, field: fieldInfo.field);
    }

    final editorBloc = FieldEditorBloc(
      fieldName: fieldInfo?.name ?? '',
      isGroupField: fieldInfo?.isGroupField ?? false,
      loader: loader,
      gridId: gridView.id,
    );
    return editorBloc;
  }

  Future<IGridCellController> makeCellController(String fieldId) async {
    final builder = await makeCellControllerBuilder(fieldId);
    return builder.build();
  }

  Future<GridCellControllerBuilder> makeCellControllerBuilder(
    String fieldId,
  ) async {
    final RowInfo rowInfo = rowInfos.last;
    final blockCache = blocks[rowInfo.rowPB.blockId];
    final rowCache = blockCache?.rowCache;
    final fieldController = _gridController.fieldController;

    final rowDataController = GridRowDataController(
      rowInfo: rowInfo,
      fieldController: fieldController,
      rowCache: rowCache!,
    );

    final rowBloc = RowBloc(
      rowInfo: rowInfo,
      dataController: rowDataController,
    )..add(const RowEvent.initial());
    await gridResponseFuture();

    return GridCellControllerBuilder(
      cellId: rowBloc.state.gridCellMap[fieldId]!,
      cellCache: rowCache.cellCache,
      delegate: rowDataController,
    );
  }

  Future<FieldEditorBloc> createField(FieldType fieldType) async {
    final editorBloc = createFieldEditor()
      ..add(const FieldEditorEvent.initial());
    await gridResponseFuture();
    editorBloc.add(FieldEditorEvent.switchToField(fieldType));
    await gridResponseFuture();
    return Future(() => editorBloc);
  }

  GridFieldInfo singleSelectFieldContext() {
    final fieldInfo = fieldContexts
        .firstWhere((element) => element.fieldType == FieldType.SingleSelect);
    return fieldInfo;
  }

  GridFieldCellContext singleSelectFieldCellContext() {
    final field = singleSelectFieldContext().field;
    return GridFieldCellContext(gridId: gridView.id, field: field);
  }

  GridFieldInfo textFieldContext() {
    final fieldInfo = fieldContexts
        .firstWhere((element) => element.fieldType == FieldType.RichText);
    return fieldInfo;
  }

  GridFieldInfo checkboxFieldContext() {
    final fieldInfo = fieldContexts
        .firstWhere((element) => element.fieldType == FieldType.Checkbox);
    return fieldInfo;
  }

  Future<GridSelectOptionCellController> makeSelectOptionCellController(
      FieldType fieldType) async {
    assert(fieldType == FieldType.SingleSelect ||
        fieldType == FieldType.MultiSelect);

    final field =
        fieldContexts.firstWhere((element) => element.fieldType == fieldType);
    final cellController =
        await makeCellController(field.id) as GridSelectOptionCellController;
    return cellController;
  }

  Future<GridCellController> makeTextCellController() async {
    final field = fieldContexts
        .firstWhere((element) => element.fieldType == FieldType.RichText);
    final cellController =
        await makeCellController(field.id) as GridCellController;
    return cellController;
  }
}

/// Create a empty Grid for test
class AppFlowyGridTest {
  final AppFlowyUnitTest unitTest;

  AppFlowyGridTest({required this.unitTest});

  static Future<AppFlowyGridTest> ensureInitialized() async {
    final inner = await AppFlowyUnitTest.ensureInitialized();
    return AppFlowyGridTest(unitTest: inner);
  }

  Future<GridTestContext> createTestGrid() async {
    final app = await unitTest.createTestApp();
    final builder = GridPluginBuilder();
    final context = await AppService()
        .createView(
      appId: app.id,
      name: "Test Grid",
      dataFormatType: builder.dataFormatType,
      pluginType: builder.pluginType,
      layoutType: builder.layoutType!,
    )
        .then((result) {
      return result.fold(
        (view) async {
          final context = GridTestContext(view, GridController(view: view));
          final result = await context._gridController.openGrid();
          result.fold((l) => null, (r) => throw Exception(r));
          return context;
        },
        (error) {
          throw Exception();
        },
      );
    });

    return context;
  }
}

/// Create a new Grid for cell test
class AppFlowyGridCellTest {
  late GridTestContext context;
  final AppFlowyGridTest gridTest;
  AppFlowyGridCellTest({required this.gridTest});

  static Future<AppFlowyGridCellTest> ensureInitialized() async {
    final gridTest = await AppFlowyGridTest.ensureInitialized();
    return AppFlowyGridCellTest(gridTest: gridTest);
  }

  Future<void> createTestGrid() async {
    context = await gridTest.createTestGrid();
  }

  Future<void> createTestRow() async {
    await context.createRow();
  }

  Future<GridSelectOptionCellController> makeCellController(
      FieldType fieldType) async {
    return context.makeSelectOptionCellController(fieldType);
  }
}

Future<void> gridResponseFuture({int milliseconds = 500}) {
  return Future.delayed(gridResponseDuration(milliseconds: milliseconds));
}

Duration gridResponseDuration({int milliseconds = 200}) {
  return Duration(milliseconds: milliseconds);
}
