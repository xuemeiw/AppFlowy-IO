import 'package:flutter/material.dart';

import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/presentation/home/menu/menu_shared_state.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'view_info_bloc.freezed.dart';

class ViewInfoBloc extends Bloc<ViewInfoEvent, ViewInfoState> {
  ViewInfoBloc() : super(ViewInfoState.initial()) {
    _viewChangedCallback =
        getIt<MenuSharedState>().addLatestViewListener(_onLatestViewChanged);

    on<ViewInfoEvent>((event, emit) {
      event.when(
        started: () {},
        registerEditorState: (editorState) {
          _wordCountService = WordCountService(editorState: editorState);
          _wordCountService!.addListener(_onWordCountChanged);
          _wordCountService!.register();

          emit(
            state.copyWith(
              documentCounters: _wordCountService!.documentCounters,
            ),
          );
        },
        reset: () {
          _wordCountService?.removeListener(_onWordCountChanged);
          _wordCountService?.dispose();
          emit(ViewInfoState.initial());
        },
        wordCountChanged: () {
          emit(
            state.copyWith(
              documentCounters: _wordCountService?.documentCounters,
            ),
          );
        },
      );
    });
  }

  // Used to remove listener when the bloc is closed
  late final VoidCallback _viewChangedCallback;

  WordCountService? _wordCountService;

  @override
  Future<void> close() async {
    _wordCountService?.removeListener(_onWordCountChanged);
    _wordCountService?.dispose();
    getIt<MenuSharedState>().removeLatestViewListener(_viewChangedCallback);
    await super.close();
  }

  void _onLatestViewChanged(ViewPB? view) {
    add(const ViewInfoEvent.reset());
  }

  void _onWordCountChanged() {
    add(const ViewInfoEvent.wordCountChanged());
  }
}

@freezed
class ViewInfoEvent with _$ViewInfoEvent {
  const factory ViewInfoEvent.started() = _Started;

  const factory ViewInfoEvent.registerEditorState({
    required EditorState editorState,
  }) = _RegisterEditorState;

  const factory ViewInfoEvent.reset() = _Reset;

  const factory ViewInfoEvent.wordCountChanged() = _WordCountChanged;
}

@freezed
class ViewInfoState with _$ViewInfoState {
  const factory ViewInfoState({
    required Counters? documentCounters,
    required DateTime? lastModifiedAt,
    required DateTime? createdAt,
  }) = _ViewInfoState;

  factory ViewInfoState.initial() => const ViewInfoState(
        documentCounters: null,
        lastModifiedAt: null,
        createdAt: null,
      );
}
