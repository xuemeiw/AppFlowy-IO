import 'package:appflowy/mobile/presentation/database/board/mobile_board_screen.dart';
import 'package:appflowy/mobile/presentation/database/mobile_calendar_screen.dart';
import 'package:appflowy/mobile/presentation/database/mobile_grid_screen.dart';
import 'package:appflowy/mobile/presentation/presentation.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-folder2/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MobileRouterRecord {
  PropertyValueNotifier<String> lastPushedRouter =
      PropertyValueNotifier<String>('');
}

extension MobileRouter on BuildContext {
  Future<void> pushView(ViewPB view) async {
    await FolderEventSetLatestView(ViewIdPB(value: view.id)).send();
    getIt<MobileRouterRecord>().lastPushedRouter.value = view.routeName;
    push(
      Uri(
        path: view.routeName,
        queryParameters: view.queryParameters,
      ).toString(),
    );
  }
}

extension on ViewPB {
  String get routeName {
    switch (layout) {
      case ViewLayoutPB.Document:
        return MobileEditorScreen.routeName;
      case ViewLayoutPB.Grid:
        return MobileGridScreen.routeName;
      case ViewLayoutPB.Calendar:
        return MobileCalendarScreen.routeName;
      case ViewLayoutPB.Board:
        return MobileBoardScreen.routeName;
      default:
        throw UnimplementedError('routeName for $this is not implemented');
    }
  }

  Map<String, dynamic> get queryParameters {
    switch (layout) {
      case ViewLayoutPB.Document:
        return {
          MobileEditorScreen.viewId: id,
          MobileEditorScreen.viewTitle: name,
        };
      case ViewLayoutPB.Grid:
        return {
          MobileGridScreen.viewId: id,
          MobileGridScreen.viewTitle: name,
        };
      case ViewLayoutPB.Calendar:
        return {
          MobileCalendarScreen.viewId: id,
          MobileCalendarScreen.viewTitle: name,
        };
      case ViewLayoutPB.Board:
        return {
          MobileBoardScreen.viewId: id,
          MobileBoardScreen.viewTitle: name,
        };
      default:
        throw UnimplementedError(
          'queryParameters for $this is not implemented',
        );
    }
  }
}
