import 'dart:convert';

import 'package:uuid/uuid.dart';

typedef BackgroundTask = Future<void> Function(Object message);

class BtmTask<T extends BackgroundEvent> {
  final String taskId;
  final String type;
  final BackgroundTask handle;
  final T Function(Map<Object?, Object?> map) converter;
  final T? args;

  BtmTask({required this.type, required this.handle, required this.converter, String? taskId, this.args}) : taskId = (taskId ?? const Uuid().v4());

  @override
  String toString() {
    return 'BtmTask(taskId: $taskId, type: $type, handle: $handle, converter: $converter, args: $args)';
  }
}

abstract class BackgroundTaskInterface {
  Stream get eventStream;
  Stream getEventStreamFor(String taskId);
  Stream<T> getEventStream<T extends BackgroundEvent>();

  Future<void> executeTask<T extends BackgroundEvent>(BtmTask<T> task);
  Future<bool> isServiceRunning();
  Future<void> startForegroundService();
  Future<void> stopForegroundService();
}

class BackgroundTaskEvent {}

abstract class BackgroundEvent {
  BackgroundEvent();
  BackgroundEvent.fromMap(Map<Object?, Object?> map);
  Map<Object?, Object?> toMap();
  String toJson() => json.encode(toMap());
}
