import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/sign_in_bloc.dart';
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ThirdPartySignInButtons extends StatelessWidget {
  final bool isMobile;
  final Alignment contentAlignment;

  /// For desktop and mobile
  const ThirdPartySignInButtons({
    Key? key,
    required this.isMobile,
    this.contentAlignment = Alignment.center,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Column(
      children: [
        _ThirdPartySignInButton(
          icon: FlowySvgs.google_mark_xl,
          labelText: 'Log in with Google',
          contentAlignment: contentAlignment,
          onPressed: () {
            getIt<KeyValueStorage>().set(KVKeys.loginType, 'supabase');
            context.read<SignInBloc>().add(
                  const SignInEvent.signedInWithOAuth('google'),
                );
          },
        ),
        const SizedBox(height: 8),
        _ThirdPartySignInButton(
          icon: isDarkMode
              ? FlowySvgs.github_mark_white_xl
              : FlowySvgs.github_mark_black_xl,
          labelText: 'Log in with GitHub',
          contentAlignment: contentAlignment,
          onPressed: () {
            getIt<KeyValueStorage>().set(KVKeys.loginType, 'supabase');
            context
                .read<SignInBloc>()
                .add(const SignInEvent.signedInWithOAuth('github'));
          },
        ),
        const SizedBox(height: 8),
        _ThirdPartySignInButton(
          icon: isDarkMode
              ? FlowySvgs.discord_mark_white_xl
              : FlowySvgs.discord_mark_blurple_xl,
          labelText: 'Log in with Discord',
          contentAlignment: contentAlignment,
          onPressed: () {
            // getIt<KeyValueStorage>().set(KVKeys.loginType, 'supabase');
            // context
            //     .read<SignInBloc>()
            //     .add(const SignInEvent.signedInWithOAuth('discord'));
          },
        ),
      ],
    );
  }
}

class _ThirdPartySignInButton extends StatelessWidget {
  const _ThirdPartySignInButton({
    Key? key,
    required this.icon,
    required this.labelText,
    required this.onPressed,
    required this.contentAlignment,
  }) : super(key: key);

  final FlowySvgData icon;
  final String labelText;
  final Alignment contentAlignment;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context);
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: FlowySvg(
          icon,
          size: const Size.square(24),
          blendMode: null,
        ),
        label: FlowyText(
          labelText,
          fontSize: 14,
        ),
        style: ButtonStyle(
          alignment: contentAlignment,
          overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(MaterialState.hovered)) {
                return style.colorScheme.onSecondaryContainer;
              }
              return null;
            },
          ),
          shape: MaterialStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: Corners.s6Border,
            ),
          ),
          side: MaterialStateProperty.all(
            BorderSide(
              color: style.dividerColor,
            ),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
