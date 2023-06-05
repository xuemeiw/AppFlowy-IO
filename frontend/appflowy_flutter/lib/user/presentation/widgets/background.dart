import 'dart:math';

import 'package:flowy_infra/image.dart';
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';

class AuthFormContainer extends StatelessWidget {
  final List<Widget> children;
  const AuthFormContainer({
    final Key? key,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox(
      width: min(size.width, 340),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class FlowyLogoTitle extends StatelessWidget {
  final String title;
  final Size logoSize;
  const FlowyLogoTitle({
    final Key? key,
    required this.title,
    this.logoSize = const Size.square(40),
  }) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    return SizedBox(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.fromSize(
            size: logoSize,
            child: svgWidget("flowy_logo"),
          ),
          const VSpace(30),
          FlowyText.semibold(
            title,
            fontSize: FontSizes.s24,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}
