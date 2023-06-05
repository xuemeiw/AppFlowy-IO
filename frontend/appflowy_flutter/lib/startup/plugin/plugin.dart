library flowy_plugin;

import 'package:appflowy/startup/plugin/plugin.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/presentation/home/home_stack.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flutter/widgets.dart';

export "./src/sandbox.dart";

enum PluginType {
  editor,
  blank,
  trash,
  grid,
  board,
  calendar,
}

typedef PluginId = String;

abstract class Plugin<T> {
  PluginId get id;

  PluginDisplay get display;

  PluginNotifier? get notifier => null;

  PluginType get ty;

  void dispose() {
    notifier?.dispose();
  }
}

abstract class PluginNotifier<T> {
  /// Notify if the plugin get deleted
  ValueNotifier<T> get isDeleted;

  /// Notify if the [PluginDisplay]'s content was changed
  ValueNotifier<int> get isDisplayChanged;

  void dispose() {}
}

abstract class PluginBuilder {
  Plugin build(final dynamic data);

  String get menuName;

  String get menuIcon;

  PluginType get pluginType;

  ViewLayoutTypePB? get layoutType => ViewLayoutTypePB.Document;
}

abstract class PluginConfig {
  // Return false will disable the user to create it. For example, a trash plugin shouldn't be created by the user,
  bool get creatable => true;
}

abstract class PluginDisplay with NavigationItem {
  List<NavigationItem> get navigationItems;

  Widget buildWidget(final PluginContext context);
}

class PluginContext {
  // calls when widget of the plugin get deleted
  final Function(ViewPB, int?) onDeleted;

  PluginContext({required this.onDeleted});
}

void registerPlugin({required final PluginBuilder builder, final PluginConfig? config}) {
  getIt<PluginSandbox>()
      .registerPlugin(builder.pluginType, builder, config: config);
}

Plugin makePlugin({required final PluginType pluginType, final dynamic data}) {
  final plugin = getIt<PluginSandbox>().buildPlugin(pluginType, data);
  return plugin;
}

List<PluginBuilder> pluginBuilders() {
  final pluginBuilders = getIt<PluginSandbox>().builders;
  final pluginConfigs = getIt<PluginSandbox>().pluginConfigs;
  return pluginBuilders.where(
    (final builder) {
      final config = pluginConfigs[builder.pluginType]?.creatable;
      return config ?? true;
    },
  ).toList();
}

enum FlowyPluginException {
  invalidData,
}
