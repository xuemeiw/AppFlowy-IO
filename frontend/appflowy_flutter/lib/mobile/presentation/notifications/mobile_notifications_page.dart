import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/application/user_profile/user_profile_bloc.dart';
import 'package:appflowy/mobile/presentation/notifications/widgets/mobile_notification_tab_bar.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/notification_filter/notification_filter_bloc.dart';
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
import 'package:appflowy/workspace/application/menu/menu_bloc.dart';
import 'package:appflowy/workspace/presentation/home/errors/workspace_failed_screen.dart';
import 'package:appflowy/workspace/presentation/notifications/reminder_extension.dart';
import 'package:appflowy/workspace/presentation/notifications/widgets/inbox_action_bar.dart';
import 'package:appflowy/workspace/presentation/notifications/widgets/notification_view.dart';
import 'package:appflowy_backend/protobuf/flowy-folder2/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/reminder.pb.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MobileNotificationsScreen extends StatefulWidget {
  const MobileNotificationsScreen({super.key});

  static const routeName = '/notifications';

  @override
  State<MobileNotificationsScreen> createState() =>
      _MobileNotificationsScreenState();
}

class _MobileNotificationsScreenState extends State<MobileNotificationsScreen>
    with SingleTickerProviderStateMixin {
  final ReminderBloc _reminderBloc = getIt<ReminderBloc>();
  late final TabController _controller = TabController(length: 2, vsync: this);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UserProfileBloc>(
          create: (context) =>
              UserProfileBloc()..add(const UserProfileEvent.started()),
        ),
        BlocProvider<ReminderBloc>.value(value: _reminderBloc),
        BlocProvider<NotificationFilterBloc>(
          create: (_) => NotificationFilterBloc(),
        ),
      ],
      child: BlocBuilder<UserProfileBloc, UserProfileState>(
        builder: (context, state) {
          return state.maybeWhen(
            orElse: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            workspaceFailure: () => const WorkspaceFailedScreen(),
            success: (workspaceSetting, userProfile) => BlocProvider(
              create: (context) => MenuBloc(
                workspaceId: workspaceSetting.workspaceId,
                user: userProfile,
              )..add(const MenuEvent.initial()),
              child: BlocBuilder<MenuBloc, MenuState>(
                builder: (context, menuState) => BlocBuilder<
                    NotificationFilterBloc, NotificationFilterState>(
                  builder: (context, filterState) =>
                      BlocBuilder<ReminderBloc, ReminderState>(
                    builder: (context, state) {
                      // Workaround for rebuilding the Blocks by brightness
                      Theme.of(context).brightness;

                      final List<ReminderPB> pastReminders = state.pastReminders
                          .where(
                            (r) =>
                                filterState.showUnreadsOnly ? !r.isRead : true,
                          )
                          .sortByScheduledAt();

                      final List<ReminderPB> upcomingReminders =
                          state.upcomingReminders.sortByScheduledAt();

                      return Scaffold(
                        appBar: AppBar(
                          automaticallyImplyLeading: false,
                          elevation: 0,
                          title: Text(
                            LocaleKeys.notificationHub_mobile_title.tr(),
                          ),
                        ),
                        body: SafeArea(
                          child: Column(
                            children: [
                              MobileNotificationTabBar(controller: _controller),
                              Expanded(
                                child: TabBarView(
                                  controller: _controller,
                                  children: [
                                    NotificationsView(
                                      shownReminders: pastReminders,
                                      reminderBloc: _reminderBloc,
                                      views: menuState.views,
                                      onAction: _onAction,
                                      onDelete: _onDelete,
                                      onReadChanged: _onReadChanged,
                                      actionBar: InboxActionBar(
                                        hasUnreads: state.hasUnreads,
                                        showUnreadsOnly:
                                            filterState.showUnreadsOnly,
                                      ),
                                    ),
                                    NotificationsView(
                                      shownReminders: upcomingReminders,
                                      reminderBloc: _reminderBloc,
                                      views: menuState.views,
                                      isUpcoming: true,
                                      onAction: _onAction,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onAction(ReminderPB reminder, int? path, ViewPB? view) =>
      _reminderBloc.add(
        ReminderEvent.pressReminder(
          reminderId: reminder.id,
          path: path,
          view: view,
        ),
      );

  void _onDelete(ReminderPB reminder) =>
      _reminderBloc.add(ReminderEvent.remove(reminder: reminder));

  void _onReadChanged(ReminderPB reminder, bool isRead) => _reminderBloc.add(
        ReminderEvent.update(ReminderUpdate(id: reminder.id, isRead: isRead)),
      );
}
