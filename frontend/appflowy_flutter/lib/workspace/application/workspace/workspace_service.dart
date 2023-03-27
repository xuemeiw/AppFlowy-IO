import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder2/app.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder2/view.pb.dart'
    show
        CreateViewPayloadPB,
        MoveFolderItemPayloadPB,
        MoveFolderItemType,
        ViewLayoutTypePB,
        ViewPB;
import 'package:appflowy_backend/protobuf/flowy-folder2/workspace.pb.dart';

import 'package:appflowy/generated/locale_keys.g.dart';

class WorkspaceService {
  final String workspaceId;
  WorkspaceService({
    required this.workspaceId,
  });
  Future<Either<ViewPB, FlowyError>> createApp(
      {required String name, String? desc}) {
    final payload = CreateViewPayloadPB.create()
      ..belongToId = workspaceId
      ..name = name
      ..desc = desc ?? ""
      ..layout = ViewLayoutTypePB.Document;

    return FolderEventCreateView(payload).send();
  }

  Future<Either<WorkspacePB, FlowyError>> getWorkspace() {
    final payload = WorkspaceIdPB.create()..value = workspaceId;
    return FolderEventReadWorkspaces(payload).send().then((result) {
      return result.fold(
        (workspaces) {
          assert(workspaces.items.length == 1);

          if (workspaces.items.isEmpty) {
            return right(FlowyError.create()
              ..msg = LocaleKeys.workspace_notFoundError.tr());
          } else {
            return left(workspaces.items[0]);
          }
        },
        (error) => right(error),
      );
    });
  }

  Future<Either<List<ViewPB>, FlowyError>> getApps() {
    final payload = WorkspaceIdPB.create()..value = workspaceId;
    return FolderEventReadWorkspaceApps(payload).send().then((result) {
      return result.fold(
        (apps) => left(apps.items),
        (error) => right(error),
      );
    });
  }

  Future<Either<Unit, FlowyError>> moveApp({
    required String appId,
    required int fromIndex,
    required int toIndex,
  }) {
    final payload = MoveFolderItemPayloadPB.create()
      ..itemId = appId
      ..from = fromIndex
      ..to = toIndex
      ..ty = MoveFolderItemType.MoveApp;

    return FolderEventMoveItem(payload).send();
  }
}
