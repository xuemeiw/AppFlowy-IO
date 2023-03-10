import 'package:appflowy/plugins/document/presentation/plugins/openai/widgets/auto_completion_node_widget.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

SelectionMenuItem autoGeneratorMenuItem = SelectionMenuItem.node(
  name: 'Auto Generator',
  iconData: Icons.generating_tokens,
  keywords: ['autogenerator', 'auto generator'],
  nodeBuilder: (editorState) {
    final node = Node(
      type: kAutoCompletionInputType,
      attributes: {
        kAutoCompletionInputString: '',
      },
    );
    return node;
  },
  replace: (_, textNode) => textNode.toPlainText().isEmpty,
  updateSelection: null,
);
