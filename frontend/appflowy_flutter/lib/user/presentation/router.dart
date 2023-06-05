import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/auth_service.dart';
import 'package:appflowy/user/presentation/sign_in_screen.dart';
import 'package:appflowy/user/presentation/sign_up_screen.dart';
import 'package:appflowy/user/presentation/skip_log_in_screen.dart';
import 'package:appflowy/user/presentation/welcome_screen.dart';
import 'package:appflowy/workspace/presentation/home/home_screen.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:flowy_infra/time/duration.dart';
import 'package:flowy_infra_ui/widget/route/animation.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart'
    show UserProfilePB;
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:flutter/material.dart';

class AuthRouter {
  void pushForgetPasswordScreen(final BuildContext context) {}

  void pushWelcomeScreen(final BuildContext context, final UserProfilePB userProfile) {
    getIt<SplashRoute>().pushWelcomeScreen(context, userProfile);
  }

  void pushSignUpScreen(final BuildContext context) {
    Navigator.of(context).push(
      PageRoutes.fade(
        () => SignUpScreen(router: getIt<AuthRouter>()),
      ),
    );
  }

  void pushHomeScreen(
    final BuildContext context,
    final UserProfilePB profile,
    final WorkspaceSettingPB workspaceSetting,
  ) {
    Navigator.push(
      context,
      PageRoutes.fade(
        () => HomeScreen(
          profile,
          workspaceSetting,
          key: ValueKey(profile.id),
        ),
        RouteDurations.slow.inMilliseconds * .001,
      ),
    );
  }
}

class SplashRoute {
  Future<void> pushWelcomeScreen(
    final BuildContext context,
    final UserProfilePB userProfile,
  ) async {
    final screen = WelcomeScreen(userProfile: userProfile);
    await Navigator.of(context).push(
      PageRoutes.fade(
        () => screen,
        RouteDurations.slow.inMilliseconds * .001,
      ),
    );

    FolderEventReadCurrentWorkspace().send().then((final result) {
      result.fold(
        (final workspaceSettingPB) =>
            pushHomeScreen(context, userProfile, workspaceSettingPB),
        (final r) => null,
      );
    });
  }

  void pushHomeScreen(
    final BuildContext context,
    final UserProfilePB userProfile,
    final WorkspaceSettingPB workspaceSetting,
  ) {
    Navigator.push(
      context,
      PageRoutes.fade(
        () => HomeScreen(
          userProfile,
          workspaceSetting,
          key: ValueKey(userProfile.id),
        ),
        RouteDurations.slow.inMilliseconds * .001,
      ),
    );
  }

  void pushSignInScreen(final BuildContext context) {
    Navigator.push(
      context,
      PageRoutes.fade(
        () => SignInScreen(router: getIt<AuthRouter>()),
        RouteDurations.slow.inMilliseconds * .001,
      ),
    );
  }

  void pushSkipLoginScreen(final BuildContext context) {
    Navigator.push(
      context,
      PageRoutes.fade(
        () => SkipLogInScreen(
          router: getIt<AuthRouter>(),
          authService: getIt<AuthService>(),
        ),
        RouteDurations.slow.inMilliseconds * .001,
      ),
    );
  }
}
