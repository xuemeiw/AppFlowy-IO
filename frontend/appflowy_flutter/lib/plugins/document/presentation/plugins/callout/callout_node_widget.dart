import 'package:appflowy/plugins/document/presentation/plugins/plugins.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const String kCalloutType = 'callout';
const String kCalloutAttrColor = 'color';
const String kCalloutAttrEmoji = 'emoji';

SelectionMenuItem calloutMenuItem = SelectionMenuItem.node(
  name: 'Callout',
  iconData: Icons.note,
  keywords: ['callout'],
  nodeBuilder: (final editorState) {
    final node = Node(type: kCalloutType);
    node.insert(TextNode.empty());
    return node;
  },
  replace: (final _, final textNode) => textNode.toPlainText().isEmpty,
  updateSelection: (final _, final path, final __, final ___) {
    return Selection.single(path: [...path, 0], startOffset: 0);
  },
);

class CalloutNodeWidgetBuilder extends NodeWidgetBuilder<Node>
    with ActionProvider<Node> {
  @override
  Widget build(final NodeWidgetContext<Node> context) {
    return _CalloutWidget(
      key: context.node.key,
      node: context.node,
      editorState: context.editorState,
    );
  }

  @override
  NodeValidator<Node> get nodeValidator => (final node) => node.type == kCalloutType;

  _CalloutWidgetState? _getState(final NodeWidgetContext<Node> context) {
    return context.node.key.currentState as _CalloutWidgetState?;
  }

  BuildContext? _getBuildContext(final NodeWidgetContext<Node> context) {
    return context.node.key.currentContext;
  }

  @override
  List<ActionMenuItem> actions(final NodeWidgetContext<Node> context) {
    return [
      ActionMenuItem.icon(
        iconData: Icons.color_lens_outlined,
        onPressed: () {
          final state = _getState(context);
          final ctx = _getBuildContext(context);
          if (state == null || ctx == null) {
            return;
          }
          final menuState = Provider.of<ActionMenuState>(ctx, listen: false);
          menuState.isPinned = true;
          state.colorPopoverController.show();
        },
        itemWrapper: (final item) {
          final state = _getState(context);
          final ctx = _getBuildContext(context);
          if (state == null || ctx == null) {
            return item;
          }
          return AppFlowyPopover(
            controller: state.colorPopoverController,
            popupBuilder: (final context) => state._buildColorPicker(),
            constraints: BoxConstraints.loose(const Size(200, 460)),
            triggerActions: 0,
            offset: const Offset(0, 30),
            child: item,
            onClose: () {
              final menuState =
                  Provider.of<ActionMenuState>(ctx, listen: false);
              menuState.isPinned = false;
            },
          );
        },
      ),
      ActionMenuItem.svg(
        name: 'delete',
        onPressed: () {
          final transaction = context.editorState.transaction
            ..deleteNode(context.node);
          context.editorState.apply(transaction);
        },
      ),
    ];
  }
}

class _CalloutWidget extends StatefulWidget {
  const _CalloutWidget({
    super.key,
    required this.node,
    required this.editorState,
  });

  final Node node;
  final EditorState editorState;

  @override
  State<_CalloutWidget> createState() => _CalloutWidgetState();
}

class _CalloutWidgetState extends State<_CalloutWidget> with SelectableMixin {
  final PopoverController colorPopoverController = PopoverController();
  final PopoverController emojiPopoverController = PopoverController();
  RenderBox get _renderBox => context.findRenderObject() as RenderBox;

  @override
  void initState() {
    widget.node.addListener(nodeChanged);
    super.initState();
  }

  @override
  void dispose() {
    widget.node.removeListener(nodeChanged);
    super.dispose();
  }

  void nodeChanged() {
    if (widget.node.children.isEmpty) {
      deleteNode();
    }
  }

  @override
  Widget build(final BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        color: tint.color(context),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 0, right: 15),
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmoji(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.node.children
                  .map(
                    (final child) => widget.editorState.service.renderPluginService
                        .buildPluginWidget(
                      child is TextNode
                          ? NodeWidgetContext<TextNode>(
                              context: context,
                              node: child,
                              editorState: widget.editorState,
                            )
                          : NodeWidgetContext<Node>(
                              context: context,
                              node: child,
                              editorState: widget.editorState,
                            ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _popover({
    required final PopoverController controller,
    required final Widget Function(BuildContext context) popupBuilder,
    required final Widget child,
    final Size size = const Size(200, 460),
  }) {
    return AppFlowyPopover(
      controller: controller,
      constraints: BoxConstraints.loose(size),
      triggerActions: 0,
      popupBuilder: popupBuilder,
      child: child,
    );
  }

  Widget _buildColorPicker() {
    return FlowyColorPicker(
      colors: FlowyTint.values
          .map(
            (final t) => ColorOption(
              color: t.color(context),
              name: t.tintName(AppFlowyEditorLocalizations.current),
            ),
          )
          .toList(),
      selected: tint.color(context),
      onTap: (final color, final index) {
        setColor(FlowyTint.values[index]);
        colorPopoverController.close();
      },
    );
  }

  Widget _buildEmoji() {
    return _popover(
      controller: emojiPopoverController,
      popupBuilder: (final context) => _buildEmojiPicker(),
      size: const Size(300, 200),
      child: FlowyTextButton(
        emoji,
        fontSize: 18,
        fillColor: Colors.transparent,
        onPressed: () {
          emojiPopoverController.show();
        },
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return EmojiSelectionMenu(
      editorState: widget.editorState,
      onSubmitted: (final emoji) {
        setEmoji(emoji.emoji);
        emojiPopoverController.close();
      },
      onExit: () {},
    );
  }

  void setColor(final FlowyTint tint) {
    final transaction = widget.editorState.transaction
      ..updateNode(widget.node, {
        kCalloutAttrColor: tint.name,
      });
    widget.editorState.apply(transaction);
  }

  void setEmoji(final String emoji) {
    final transaction = widget.editorState.transaction
      ..updateNode(widget.node, {
        kCalloutAttrEmoji: emoji,
      });
    widget.editorState.apply(transaction);
  }

  void deleteNode() {
    final transaction = widget.editorState.transaction..deleteNode(widget.node);
    widget.editorState.apply(transaction);
  }

  FlowyTint get tint {
    final name = widget.node.attributes[kCalloutAttrColor];
    return (name is String) ? FlowyTint.fromJson(name) : FlowyTint.tint1;
  }

  String get emoji {
    return widget.node.attributes[kCalloutAttrEmoji] ?? "💡";
  }

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(final Offset start) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.borderLine;

  @override
  Rect? getCursorRectInPosition(final Position position) {
    final size = _renderBox.size;
    return Rect.fromLTWH(-size.width / 2.0, 0, size.width, size.height);
  }

  @override
  List<Rect> getRectsInSelection(final Selection selection) =>
      [Offset.zero & _renderBox.size];

  @override
  Selection getSelectionInRange(final Offset start, final Offset end) => Selection.single(
        path: widget.node.path,
        startOffset: 0,
        endOffset: 1,
      );

  @override
  Offset localToGlobal(final Offset offset) => _renderBox.localToGlobal(offset);
}
