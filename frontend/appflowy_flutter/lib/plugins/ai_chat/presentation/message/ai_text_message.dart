import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_ai_message_bloc.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_bloc.dart';
import 'package:appflowy/plugins/ai_chat/presentation/chat_loading.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/style_widget/button.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart';
import 'package:markdown_widget/markdown_widget.dart';

class ChatAITextMessageWidget extends StatelessWidget {
  const ChatAITextMessageWidget({
    super.key,
    required this.user,
    required this.messageUserId,
    required this.text,
    required this.questionId,
    required this.chatId,
  });

  final User user;
  final String messageUserId;
  final dynamic text;
  final Int64? questionId;
  final String chatId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatAIMessageBloc(
        message: text,
        chatId: chatId,
        questionId: questionId,
      )..add(const ChatAIMessageEvent.initial()),
      child: BlocBuilder<ChatAIMessageBloc, ChatAIMessageState>(
        builder: (context, state) {
          if (state.error != null) {
            return StreamingError(
              onRetryPressed: () {
                context.read<ChatAIMessageBloc>().add(
                      const ChatAIMessageEvent.retry(),
                    );
              },
            );
          }

          if (state.retryState == const LoadingState.loading()) {
            return const ChatAILoading();
          }

          if (state.text.isEmpty) {
            return const ChatAILoading();
          } else {
            return _textWidgetBuilder(user, context, state.text);
          }
        },
      ),
    );
  }

  Widget _textWidgetBuilder(
    User user,
    BuildContext context,
    String text,
  ) {
    return MarkdownWidget(
      data: text,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      config: configFromContext(context),
    );
  }

  MarkdownConfig configFromContext(BuildContext context) {
    return MarkdownConfig(
      configs: [
        HrConfig(color: AFThemeExtension.of(context).textColor),
        ChatH1Config(
          style: TextStyle(
            color: AFThemeExtension.of(context).textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
          dividerColor: AFThemeExtension.of(context).lightGreyHover,
        ),
        ChatH2Config(
          style: TextStyle(
            color: AFThemeExtension.of(context).textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
          dividerColor: AFThemeExtension.of(context).lightGreyHover,
        ),
        ChatH3Config(
          style: TextStyle(
            color: AFThemeExtension.of(context).textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
          dividerColor: AFThemeExtension.of(context).lightGreyHover,
        ),
        H4Config(
          style: TextStyle(
            color: AFThemeExtension.of(context).textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        H5Config(
          style: TextStyle(
            color: AFThemeExtension.of(context).textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        H6Config(
          style: TextStyle(
            color: AFThemeExtension.of(context).textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        PreConfig(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.6),
            borderRadius: const BorderRadius.all(
              Radius.circular(8.0),
            ),
          ),
        ),
        PConfig(
          textStyle: TextStyle(
            color: AFThemeExtension.of(context).textColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        CodeConfig(
          style: TextStyle(
            color: AFThemeExtension.of(context).textColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        BlockquoteConfig(
          sideColor: AFThemeExtension.of(context).lightGreyHover,
          textColor: AFThemeExtension.of(context).textColor,
        ),
      ],
    );
  }
}

class ChatH1Config extends HeadingConfig {
  const ChatH1Config({
    this.style = const TextStyle(
      fontSize: 32,
      height: 40 / 32,
      fontWeight: FontWeight.bold,
    ),
    required this.dividerColor,
  });

  @override
  final TextStyle style;
  final Color dividerColor;

  @override
  String get tag => MarkdownTag.h1.name;

  @override
  HeadingDivider? get divider => HeadingDivider(
        space: 10,
        color: dividerColor,
        height: 10,
      );
}

///config class for h2
class ChatH2Config extends HeadingConfig {
  const ChatH2Config({
    this.style = const TextStyle(
      fontSize: 24,
      height: 30 / 24,
      fontWeight: FontWeight.bold,
    ),
    required this.dividerColor,
  });
  @override
  final TextStyle style;
  final Color dividerColor;

  @override
  String get tag => MarkdownTag.h2.name;

  @override
  HeadingDivider? get divider => HeadingDivider(
        space: 10,
        color: dividerColor,
        height: 10,
      );
}

class ChatH3Config extends HeadingConfig {
  const ChatH3Config({
    this.style = const TextStyle(
      fontSize: 24,
      height: 30 / 24,
      fontWeight: FontWeight.bold,
    ),
    required this.dividerColor,
  });

  @override
  final TextStyle style;
  final Color dividerColor;

  @override
  String get tag => MarkdownTag.h3.name;

  @override
  HeadingDivider? get divider => HeadingDivider(
        space: 10,
        color: dividerColor,
        height: 10,
      );
}

class StreamingError extends StatelessWidget {
  const StreamingError({
    required this.onRetryPressed,
    super.key,
  });

  final void Function() onRetryPressed;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 4, thickness: 1),
        const VSpace(16),
        Center(
          child: Column(
            children: [
              _aiUnvaliable(),
              const VSpace(10),
              _retryButton(),
            ],
          ),
        ),
      ],
    );
  }

  FlowyButton _retryButton() {
    return FlowyButton(
      radius: BorderRadius.circular(20),
      useIntrinsicWidth: true,
      text: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: FlowyText(
          LocaleKeys.chat_regenerateAnswer.tr(),
          fontSize: 14,
        ),
      ),
      onTap: onRetryPressed,
      iconPadding: 0,
      leftIcon: const Icon(
        Icons.refresh,
        size: 20,
      ),
    );
  }

  Padding _aiUnvaliable() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FlowyText(
        LocaleKeys.chat_aiServerUnavailable.tr(),
        fontSize: 14,
      ),
    );
  }
}
