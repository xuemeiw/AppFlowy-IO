import 'package:appflowy/plugins/database_view/application/field_settings/field_settings_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/field_entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/field_settings_entities.pbenum.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'field_controller.dart';
import 'field_info.dart';
import 'field_listener.dart';
import 'field_service.dart';
import 'type_option/type_option_context.dart';
import 'type_option/type_option_data_controller.dart';

part 'field_editor_bloc.freezed.dart';

class FieldEditorBloc extends Bloc<FieldEditorEvent, FieldEditorState> {
  FieldInfo field;

  final String viewId;
  final FieldController fieldController;
  final SingleFieldListener _singleFieldListener;
  final FieldBackendService fieldService;
  final FieldSettingsBackendService fieldSettingsService;
  final TypeOptionController typeOptionController;

  FieldEditorBloc({
    required this.viewId,
    required this.field,
    required this.fieldController,
    required FieldTypeOptionLoader loader,
  })  : typeOptionController = TypeOptionController(
          field: field.field,
          loader: loader,
        ),
        _singleFieldListener = SingleFieldListener(fieldId: field.id),
        fieldService = FieldBackendService(
          viewId: viewId,
          fieldId: field.id,
        ),
        fieldSettingsService = FieldSettingsBackendService(viewId: viewId),
        super(FieldEditorState(field: field)) {
    on<FieldEditorEvent>(
      (event, emit) async {
        await event.when(
          initial: () async {
            typeOptionController.addFieldListener((field) {
              if (!isClosed) {
                add(FieldEditorEvent.didReceiveFieldChanged(field));
              }
            });
            _singleFieldListener.start(
              onFieldChanged: (field) {
                if (!isClosed) {
                  add(FieldEditorEvent.didReceiveFieldChanged(field));
                }
              },
            );
            await typeOptionController.reloadTypeOption();
            add(FieldEditorEvent.didReceiveFieldChanged(field.field));
          },
          didReceiveFieldChanged: (field) {
            emit(state.copyWith(field: fieldController.getField(field.id)!));
          },
          switchFieldType: (fieldType) async {
            await typeOptionController.switchToField(fieldType);
          },
          renameField: (newName) async {
            final result = await fieldService.updateField(name: newName);
            _logIfError(result);
          },
          toggleFieldVisibility: () async {
            final currentVisibility =
                state.field.visibility ?? FieldVisibility.AlwaysShown;
            final newVisibility =
                currentVisibility == FieldVisibility.AlwaysHidden
                    ? FieldVisibility.AlwaysShown
                    : FieldVisibility.AlwaysHidden;
            final result = await fieldSettingsService.updateFieldSettings(
              fieldId: field.id,
              fieldVisibility: newVisibility,
            );
            _logIfError(result);
          },
          deleteField: () async {
            final result = await fieldService.deleteField();
            _logIfError(result);
          },
          duplicateField: () async {
            final result = await fieldService.duplicateField();
            _logIfError(result);
          },
        );
      },
    );
  }

  void _logIfError(Either<Unit, FlowyError> result) {
    result.fold(
      (l) => null,
      (err) => Log.error(err),
    );
  }

  @override
  Future<void> close() {
    _singleFieldListener.stop();
    return super.close();
  }
}

@freezed
class FieldEditorEvent with _$FieldEditorEvent {
  const factory FieldEditorEvent.initial() = _InitialField;
  const factory FieldEditorEvent.didReceiveFieldChanged(FieldPB field) =
      _DidReceiveFieldChanged;
  const factory FieldEditorEvent.switchFieldType(FieldType fieldType) =
      _SwitchFieldType;
  const factory FieldEditorEvent.renameField(String name) = _RenameField;
  const factory FieldEditorEvent.toggleFieldVisibility() =
      _ToggleFieldVisiblity;
  const factory FieldEditorEvent.deleteField() = _DeleteField;
  const factory FieldEditorEvent.duplicateField() = _DuplicateField;
}

@freezed
class FieldEditorState with _$FieldEditorState {
  const factory FieldEditorState({
    required FieldInfo field,
  }) = _FieldEditorState;
}
