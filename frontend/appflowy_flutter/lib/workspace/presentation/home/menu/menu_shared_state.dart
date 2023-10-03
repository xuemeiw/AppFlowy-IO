import 'package:appflowy_backend/protobuf/flowy-folder2/view.pb.dart';
import 'package:flutter/material.dart';

class MenuSharedState {
  final ValueNotifier<ViewPB?> _latestOpenView = ValueNotifier<ViewPB?>(null);
  final ValueNotifier<Map<String, List<String>>> _openPlugins =
      ValueNotifier<Map<String, List<String>>>({});

  MenuSharedState({ViewPB? view}) {
    _latestOpenView.value = view;
  }

  ViewPB? get latestOpenView => _latestOpenView.value;
  ValueNotifier<ViewPB?> get notifier => _latestOpenView;

  set latestOpenView(ViewPB? view) {
    if (_latestOpenView.value?.id != view?.id) {
      _latestOpenView.value = view;
    }
  }

  VoidCallback addLatestViewListener(void Function(ViewPB?) callback) {
    listener() {
      callback(_latestOpenView.value);
    }

    _latestOpenView.addListener(listener);
    return listener;
  }

  void removeLatestViewListener(VoidCallback listener) {
    _latestOpenView.removeListener(listener);
  }

  VoidCallback addPluginListListener(
    void Function(Map<String, List<String>>) callback,
  ) {
    listener() {
      callback(_openPlugins.value);
    }

    _openPlugins.addListener(listener);
    return listener;
  }

  void removePluginListListener(VoidCallback listener) {
    _openPlugins.removeListener(listener);
  }

  Map<String, List<String>> get openPlugins => _openPlugins.value;

  set openPlugins(Map<String, List<String>> value) {
    _openPlugins.value = value;
  }
}
