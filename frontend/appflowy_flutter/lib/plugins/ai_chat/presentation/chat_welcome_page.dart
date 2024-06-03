import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flutter/material.dart';

class ChatWelcomePage extends StatelessWidget {
  ChatWelcomePage({required this.onSelectedQuestion, super.key});

  final void Function(String) onSelectedQuestion;

  final List<String> items = [
    LocaleKeys.chat_question1.tr(),
    LocaleKeys.chat_question1.tr(),
    LocaleKeys.chat_question1.tr(),
    LocaleKeys.chat_question1.tr(),
  ];
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FlowySvg(
            FlowySvgs.flowy_ai_chat_logo_s,
            size: Size.square(44),
          ),
          const SizedBox(height: 40),
          GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 6,
              mainAxisSpacing: 2,
              childAspectRatio: 16.0 / 9.0,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => WelcomeQuestion(
              question: items[index],
              onSelected: onSelectedQuestion,
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeQuestion extends StatelessWidget {
  const WelcomeQuestion({
    required this.question,
    required this.onSelected,
    super.key,
  });

  final void Function(String) onSelected;
  final String question;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelected(question),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: FlowyHover(
          style: HoverStyle(
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FlowyText(
                  question,
                  maxLines: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
