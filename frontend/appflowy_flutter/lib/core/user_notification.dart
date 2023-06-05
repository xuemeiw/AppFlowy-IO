import 'dart:async';
import 'dart:typed_data';
import 'package:appflowy_backend/protobuf/flowy-notification/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:dartz/dartz.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/rust_stream.dart';

import 'notification_helper.dart';

// User
typedef UserNotificationCallback = void Function(
  UserNotification,
  Either<Uint8List, FlowyError>,
);

class UserNotificationParser
    extends NotificationParser<UserNotification, FlowyError> {
  UserNotificationParser({
    required final String id,
    required final UserNotificationCallback callback,
  }) : super(
          id: id,
          callback: callback,
          tyParser: (final ty) => UserNotification.valueOf(ty),
          errorParser: (final bytes) => FlowyError.fromBuffer(bytes),
        );
}

typedef UserNotificationHandler = Function(
  UserNotification ty,
  Either<Uint8List, FlowyError> result,
);

class UserNotificationListener {
  StreamSubscription<SubscribeObject>? _subscription;
  UserNotificationParser? _parser;

  UserNotificationListener({
    required final String objectId,
    required final UserNotificationHandler handler,
  }) : _parser = UserNotificationParser(id: objectId, callback: handler) {
    _subscription =
        RustStreamReceiver.listen((final observable) => _parser?.parse(observable));
  }

  Future<void> stop() async {
    _parser = null;
    await _subscription?.cancel();
  }
}
