import 'package:appflowy_backend/protobuf/flowy-database/field_entities.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:async';

import 'type_option/type_option_data_controller.dart';
part 'field_type_option_edit_bloc.freezed.dart';

class FieldTypeOptionEditBloc
    extends Bloc<FieldTypeOptionEditEvent, FieldTypeOptionEditState> {
  final TypeOptionController _dataController;
  void Function()? _fieldListenFn;

  FieldTypeOptionEditBloc(final TypeOptionController dataController)
      : _dataController = dataController,
        super(FieldTypeOptionEditState.initial(dataController)) {
    on<FieldTypeOptionEditEvent>(
      (final event, final emit) async {
        event.when(
          initial: () {
            _fieldListenFn = dataController.addFieldListener((final field) {
              add(FieldTypeOptionEditEvent.didReceiveFieldUpdated(field));
            });
          },
          didReceiveFieldUpdated: (final field) {
            emit(state.copyWith(field: field));
          },
          switchToField: (final FieldType fieldType) async {
            await _dataController.switchToField(fieldType);
          },
        );
      },
    );
  }

  @override
  Future<void> close() async {
    if (_fieldListenFn != null) {
      _dataController.removeFieldListener(_fieldListenFn!);
    }
    return super.close();
  }
}

@freezed
class FieldTypeOptionEditEvent with _$FieldTypeOptionEditEvent {
  const factory FieldTypeOptionEditEvent.initial() = _Initial;
  const factory FieldTypeOptionEditEvent.switchToField(final FieldType fieldType) =
      _SwitchToField;
  const factory FieldTypeOptionEditEvent.didReceiveFieldUpdated(final FieldPB field) =
      _DidReceiveFieldUpdated;
}

@freezed
class FieldTypeOptionEditState with _$FieldTypeOptionEditState {
  const factory FieldTypeOptionEditState({
    required final FieldPB field,
  }) = _FieldTypeOptionEditState;

  factory FieldTypeOptionEditState.initial(
    final TypeOptionController typeOptionController,
  ) =>
      FieldTypeOptionEditState(
        field: typeOptionController.field,
      );
}
