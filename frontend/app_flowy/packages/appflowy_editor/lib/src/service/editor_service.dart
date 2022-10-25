import 'package:appflowy_editor/src/flutter/overlay.dart';
import 'package:appflowy_editor/src/render/image/image_node_builder.dart';
import 'package:appflowy_editor/src/render/selection_menu/selection_menu_widget.dart';
import 'package:appflowy_editor/src/render/style/editor_style.dart';
import 'package:appflowy_editor/src/service/shortcut_event/built_in_shortcut_events.dart';
import 'package:appflowy_editor/src/service/shortcut_event/shortcut_event.dart';
import 'package:flutter/material.dart' hide Overlay, OverlayEntry;

import 'package:appflowy_editor/src/editor_state.dart';
import 'package:appflowy_editor/src/render/editor/editor_entry.dart';
import 'package:appflowy_editor/src/render/rich_text/bulleted_list_text.dart';
import 'package:appflowy_editor/src/render/rich_text/checkbox_text.dart';
import 'package:appflowy_editor/src/render/rich_text/heading_text.dart';
import 'package:appflowy_editor/src/render/rich_text/number_list_text.dart';
import 'package:appflowy_editor/src/render/rich_text/quoted_text.dart';
import 'package:appflowy_editor/src/render/rich_text/rich_text.dart';
import 'package:appflowy_editor/src/service/input_service.dart';
import 'package:appflowy_editor/src/service/keyboard_service.dart';
import 'package:appflowy_editor/src/service/render_plugin_service.dart';
import 'package:appflowy_editor/src/service/scroll_service.dart';
import 'package:appflowy_editor/src/service/selection_service.dart';
import 'package:appflowy_editor/src/service/toolbar_service.dart';

NodeWidgetBuilders defaultBuilders = {
  'editor': EditorEntryWidgetBuilder(),
  'text': RichTextNodeWidgetBuilder(),
  'text/checkbox': CheckboxNodeWidgetBuilder(),
  'text/heading': HeadingTextNodeWidgetBuilder(),
  'text/bulleted-list': BulletedListTextNodeWidgetBuilder(),
  'text/number-list': NumberListTextNodeWidgetBuilder(),
  'text/quote': QuotedTextNodeWidgetBuilder(),
  'image': ImageNodeBuilder(),
};

class AppFlowyEditor extends StatefulWidget {
  const AppFlowyEditor({
    Key? key,
    required this.editorState,
    this.customBuilders = const {},
    this.shortcutEvents = const [],
    this.selectionMenuItems = const [],
    this.editable = true,
    required this.editorStyle,
  }) : super(key: key);

  final EditorState editorState;

  /// Render plugins.
  final NodeWidgetBuilders customBuilders;

  /// Keyboard event handlers.
  final List<ShortcutEvent> shortcutEvents;

  final List<SelectionMenuItem> selectionMenuItems;

  final EditorStyle editorStyle;

  final bool editable;

  @override
  State<AppFlowyEditor> createState() => _AppFlowyEditorState();
}

class _AppFlowyEditorState extends State<AppFlowyEditor> {
  Widget? services;

  EditorState get editorState => widget.editorState;

  @override
  void initState() {
    super.initState();

    editorState.selectionMenuItems = widget.selectionMenuItems;
    editorState.editorStyle = widget.editorStyle;
    editorState.service.renderPluginService = _createRenderPlugin();
    editorState.editable = widget.editable;
  }

  @override
  void didUpdateWidget(covariant AppFlowyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (editorState.service != oldWidget.editorState.service) {
      editorState.selectionMenuItems = widget.selectionMenuItems;
      editorState.service.renderPluginService = _createRenderPlugin();
    }

    editorState.editorStyle = widget.editorStyle;
    editorState.editable = widget.editable;
    services = null;
  }

  @override
  Widget build(BuildContext context) {
    services ??= _buildServices(context);
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => services!,
        ),
      ],
    );
  }

  AppFlowyScroll _buildServices(BuildContext context) {
    return AppFlowyScroll(
      key: editorState.service.scrollServiceKey,
      child: Padding(
        padding: widget.editorStyle.padding,
        child: AppFlowySelection(
          key: editorState.service.selectionServiceKey,
          cursorColor: widget.editorStyle.cursorColor,
          selectionColor: widget.editorStyle.selectionColor,
          editorState: editorState,
          editable: widget.editable,
          child: AppFlowyInput(
            key: editorState.service.inputServiceKey,
            editorState: editorState,
            editable: widget.editable,
            child: AppFlowyKeyboard(
              key: editorState.service.keyboardServiceKey,
              editable: widget.editable,
              shortcutEvents: [
                ...widget.shortcutEvents,
                ...builtInShortcutEvents,
              ],
              editorState: editorState,
              child: FlowyToolbar(
                key: editorState.service.toolbarServiceKey,
                editorState: editorState,
                child:
                    editorState.service.renderPluginService.buildPluginWidget(
                  NodeWidgetContext(
                    context: context,
                    node: editorState.document.root,
                    editorState: editorState,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppFlowyRenderPlugin _createRenderPlugin() => AppFlowyRenderPlugin(
        editorState: editorState,
        builders: {
          ...defaultBuilders,
          ...widget.customBuilders,
        },
      );
}
