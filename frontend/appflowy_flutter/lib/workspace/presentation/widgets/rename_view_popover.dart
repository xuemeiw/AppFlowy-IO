import 'package:flutter/widgets.dart';

import 'package:appflowy/plugins/document/presentation/editor_plugins/base/emoji_picker_button.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:flowy_infra_ui/style_widget/text_field.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';

class RenameViewPopover extends StatefulWidget {
  const RenameViewPopover({
    super.key,
    required this.viewId,
    required this.name,
    required this.popoverController,
    required this.emoji,
    this.icon,
    this.showIconChanger = true,
  });

  final String viewId;
  final String name;
  final PopoverController popoverController;
  final String emoji;
  final Widget? icon;
  final bool showIconChanger;

  @override
  State<RenameViewPopover> createState() => _RenameViewPopoverState();
}

class _RenameViewPopoverState extends State<RenameViewPopover> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.name;
    _controller.selection =
        TextSelection(baseOffset: 0, extentOffset: widget.name.length);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showIconChanger) ...[
          EmojiPickerButton(
            emoji: widget.emoji,
            defaultIcon: widget.icon,
            direction: PopoverDirection.bottomWithCenterAligned,
            offset: const Offset(0, 18),
            onSubmitted: (emoji, _) async {
              await ViewBackendService.updateViewIcon(
                viewId: widget.viewId,
                viewIcon: emoji,
              );
              widget.popoverController.close();
            },
          ),
          const HSpace(6),
        ],
        SizedBox(
          height: 36.0,
          width: 220,
          child: FlowyTextField(
            controller: _controller,
            onSubmitted: (text) async {
              if (text.isNotEmpty && text != widget.name) {
                await ViewBackendService.updateView(
                  viewId: widget.viewId,
                  name: text,
                );
              }
              widget.popoverController.close();
            },
            onCanceled: () async {
              if (_controller.text.isNotEmpty &&
                  _controller.text != widget.name) {
                await ViewBackendService.updateView(
                  viewId: widget.viewId,
                  name: _controller.text,
                );
                widget.popoverController.close();
              }
            },
          ),
        ),
      ],
    );
  }
}
