import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/util/color_to_hex_string.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/widget/dialog/styled_dialogs.dart';
import 'package:flutter/material.dart';

class DocumentColorSettingButton extends StatelessWidget {
  const DocumentColorSettingButton({
    super.key,
    required this.currentColor,
    required this.previewWidgetBuilder,
    required this.dialogTitle,
    required this.onApply,
  });

  /// current color from backend
  final Color currentColor;

  /// Build a preview widget with the given color
  /// It shows both on the [DocumentColorSettingButton] and [_DocumentColorSettingDialog]
  final Widget Function(Color? color) previewWidgetBuilder;

  final String dialogTitle;

  final void Function(Color selectedColorOnDialog) onApply;

  @override
  Widget build(BuildContext context) {
    return FlowyButton(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      text: previewWidgetBuilder.call(currentColor),
      hoverColor: Theme.of(context).colorScheme.secondaryContainer,
      expandText: false,
      onTap: () => Dialogs.show(
        context,
        child: _DocumentColorSettingDialog(
          currentColor: currentColor,
          previewWidgetBuilder: previewWidgetBuilder,
          dialogTitle: dialogTitle,
          onApply: onApply,
        ),
      ),
    );
  }
}

class _DocumentColorSettingDialog extends StatefulWidget {
  const _DocumentColorSettingDialog({
    required this.currentColor,
    required this.previewWidgetBuilder,
    required this.dialogTitle,
    required this.onApply,
  });

  final Color currentColor;

  final Widget Function(Color?) previewWidgetBuilder;

  final String dialogTitle;

  final void Function(Color selectedColorOnDialog) onApply;

  @override
  State<_DocumentColorSettingDialog> createState() =>
      DocumentColorSettingDialogState();
}

class DocumentColorSettingDialogState
    extends State<_DocumentColorSettingDialog> {
  /// The color displayed in the dialog.
  /// It is `null` when the user didn't enter a valid color value.
  late Color? selectedColorOnDialog;
  late String currentColorHexString;
  late TextEditingController hexController;
  late TextEditingController opacityController;
  final _formKey = GlobalKey<FormState>(debugLabel: 'colorSettingForm');

  @override
  void initState() {
    super.initState();
    selectedColorOnDialog = widget.currentColor;
    currentColorHexString = widget.currentColor.toHexString();
    hexController = TextEditingController(
      text: _extractColorHex(currentColorHexString),
    );
    opacityController = TextEditingController(
      text: _convertHexToOpacity(currentColorHexString),
    );
  }

  @override
  void dispose() {
    hexController.dispose();
    opacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void updateSelectedColor() {
      if (_formKey.currentState!.validate()) {
        setState(() {
          final colorValue = int.tryParse(
            _combineColorHexAndOpacity(
              hexController.text,
              opacityController.text,
            ),
          );
          // colorValue has been validated in the _ColorSettingTextField for hex value and it won't be null as this point
          selectedColorOnDialog = Color(colorValue!);
        });
      }
    }

    return FlowyDialog(
      constraints: const BoxConstraints(maxWidth: 360, maxHeight: 320),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            FlowyText(widget.dialogTitle),
            const VSpace(8),
            SizedBox(
              width: 100,
              height: 40,
              child: Center(
                child: widget.previewWidgetBuilder(
                  selectedColorOnDialog,
                ),
              ),
            ),
            const VSpace(8),
            SizedBox(
              height: 160,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _ColorSettingTextField(
                      controller: hexController,
                      labelText: LocaleKeys.editor_hexValue.tr(),
                      hintText: '6fc9e7',
                      onFieldSubmitted: (_) => updateSelectedColor(),
                      validator: (value) => validateHexValue(
                        value,
                        hexController.text,
                        opacityController.text,
                      ),
                    ),
                    const VSpace(8),
                    _ColorSettingTextField(
                      controller: opacityController,
                      labelText: LocaleKeys.editor_opacity.tr(),
                      hintText: '50',
                      onFieldSubmitted: (_) => updateSelectedColor(),
                      validator: (value) => validateOpacityValue(value),
                    ),
                  ],
                ),
              ),
            ),
            const VSpace(8),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  if (selectedColorOnDialog != null &&
                      selectedColorOnDialog != widget.currentColor) {
                    widget.onApply.call(selectedColorOnDialog!);
                  }
                } else {
                  // error message will be shown
                  return;
                }
                Navigator.of(context).pop();
              },
              child: Text(
                LocaleKeys.settings_appearance_documentSettings_apply.tr(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSettingTextField extends StatelessWidget {
  const _ColorSettingTextField({
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.onFieldSubmitted,
    required this.validator,
  });

  final TextEditingController controller;
  final String labelText;
  final String hintText;

  final void Function(String) onFieldSubmitted;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context);
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: style.colorScheme.outline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: style.colorScheme.outline,
          ),
        ),
      ),
      style: style.textTheme.bodyMedium,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}

String? validateHexValue(
  String? value,
  String hexValue,
  String opacityValue,
) {
  if (value == null || value.isEmpty) {
    return LocaleKeys.settings_appearance_documentSettings_hexEmptyError.tr();
  }
  if (value.length != 6) {
    return LocaleKeys.settings_appearance_documentSettings_hexLengthError.tr();
  }

  final colorValue = int.tryParse(
    _combineColorHexAndOpacity(
      hexValue,
      opacityValue,
    ),
  );

  if (colorValue == null) {
    return LocaleKeys.settings_appearance_documentSettings_hexInvalidError.tr();
  }

  return null;
}

String? validateOpacityValue(String? value) {
  if (value == null || value.isEmpty) {
    return LocaleKeys.settings_appearance_documentSettings_opacityEmptyError
        .tr();
  }
  if (int.tryParse(value) == null ||
      int.parse(value) > 100 ||
      int.parse(value) <= 0) {
    return LocaleKeys.settings_appearance_documentSettings_opacityRangeError
        .tr();
  }
  return null;
}

String _combineColorHexAndOpacity(String colorHex, String opacity) {
  final opacityHex = (int.parse(opacity) * 2.55).round().toRadixString(16);
  return '0x$opacityHex$colorHex';
}

// same convert functions as in appflowy_editor
String? _extractColorHex(String? colorHex) {
  if (colorHex == null) return null;
  return colorHex.substring(4);
}

String? _convertHexToOpacity(String? colorHex) {
  if (colorHex == null) return null;
  final opacityHex = colorHex.substring(2, 4);
  final opacity = int.parse(opacityHex, radix: 16) / 2.55;
  return opacity.toStringAsFixed(0);
}
