import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database_view/calendar/application/calendar_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/image.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'calendar_day.dart';
import 'layout/sizes.dart';
import 'toolbar/calendar_toolbar.dart';

class CalendarPage extends StatefulWidget {
  final ViewPB view;
  const CalendarPage({required this.view, super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _eventController = EventController<CalendarDayEvent>();
  GlobalKey<MonthViewState>? _calendarState;
  late CalendarBloc _calendarBloc;

  @override
  void initState() {
    _calendarState = GlobalKey<MonthViewState>();
    _calendarBloc = CalendarBloc(view: widget.view)
      ..add(const CalendarEvent.initial());

    super.initState();
  }

  @override
  void dispose() {
    _calendarBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CalendarControllerProvider(
      controller: _eventController,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<CalendarBloc>.value(
            value: _calendarBloc,
          )
        ],
        child: BlocListener<CalendarBloc, CalendarState>(
          listenWhen: (previous, current) => previous.events != current.events,
          listener: (context, state) {
            if (state.events.isNotEmpty) {
              _eventController.removeWhere((element) => true);
              _eventController.addAll(state.events);
            }
          },
          child: BlocBuilder<CalendarBloc, CalendarState>(
            builder: (context, state) {
              return Column(
                children: [
                  // const _ToolbarBlocAdaptor(),
                  _toolbar(),
                  _buildCalendar(_eventController),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    return const CalendarToolbar();
  }

  Widget _buildCalendar(EventController eventController) {
    return Expanded(
      child: MonthView(
        key: _calendarState,
        controller: _eventController,
        cellAspectRatio: .9,
        borderColor: Theme.of(context).dividerColor,
        headerBuilder: _headerNavigatorBuilder,
        weekDayBuilder: _headerWeekDayBuilder,
        cellBuilder: _calendarDayBuilder,
      ),
    );
  }

  Widget _headerNavigatorBuilder(DateTime currentMonth) {
    return Row(
      children: [
        FlowyText.medium(
          DateFormat('MMMM y', context.locale.toLanguageTag())
              .format(currentMonth),
        ),
        const Spacer(),
        FlowyIconButton(
          width: CalendarSize.navigatorButtonWidth,
          height: CalendarSize.navigatorButtonHeight,
          icon: svgWidget('home/arrow_left'),
          tooltipText: LocaleKeys.calendar_navigation_previousMonth.tr(),
          hoverColor: AFThemeExtension.of(context).lightGreyHover,
          onPressed: () => _calendarState?.currentState?.previousPage(),
        ),
        FlowyTextButton(
          LocaleKeys.calendar_navigation_today.tr(),
          fillColor: Colors.transparent,
          fontWeight: FontWeight.w500,
          tooltip: LocaleKeys.calendar_navigation_jumpToday.tr(),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          hoverColor: AFThemeExtension.of(context).lightGreyHover,
          onPressed: () =>
              _calendarState?.currentState?.animateToMonth(DateTime.now()),
        ),
        FlowyIconButton(
          width: CalendarSize.navigatorButtonWidth,
          height: CalendarSize.navigatorButtonHeight,
          icon: svgWidget('home/arrow_right'),
          tooltipText: LocaleKeys.calendar_navigation_nextMonth.tr(),
          hoverColor: AFThemeExtension.of(context).lightGreyHover,
          onPressed: () => _calendarState?.currentState?.nextPage(),
        ),
      ],
    );
  }

  Widget _headerWeekDayBuilder(day) {
    final symbols = DateFormat.EEEE(context.locale.toLanguageTag()).dateSymbols;
    final weekDayString = symbols.WEEKDAYS[day];
    return Center(
      child: Padding(
        padding: CalendarSize.daysOfWeekInsets,
        child: FlowyText.medium(
          weekDayString,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }

  Widget _calendarDayBuilder(
    DateTime date,
    List<CalendarEventData<CalendarDayEvent>> calenderEvents,
    isToday,
    isInMonth,
  ) {
    final events = calenderEvents.map((value) => value.event!).toList();

    return CalendarDayCard(
      viewId: widget.view.id,
      isToday: isToday,
      isInMonth: isInMonth,
      events: events,
      date: date,
      rowCache: _calendarBloc.rowCache,
      onCreateEvent: (date) {
        _calendarBloc.add(
          CalendarEvent.createEvent(
            date,
            LocaleKeys.calendar_defaultNewCalendarTitle.tr(),
          ),
        );
      },
    );
  }
}
