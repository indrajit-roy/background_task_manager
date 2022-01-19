import 'dart:convert';

import 'package:background_task_manager/models/background_event.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import 'package:background_task_manager/extensions/background_extensions.dart';

import '../models/background_data_field.dart';

typedef BackgroundTask = Future<void> Function(Object? message);
typedef PlatformArguments = Map<String, BackgroundDataField>?;
// ignore: constant_identifier_names
enum BtmTaskStatus { RUNNING, ENQUEUED, BLOCKED, CANCELLED, FAILED, SUCCEEDED }

abstract class BackgroundTaskInterface {
  // Stream get progressStream;
  // Stream get resultStream;
  Stream<BackgroundEvent> getProgressStreamFor(String taskId);
  Stream<BackgroundEvent> getResultStreamFor(String taskId);
  Stream<BackgroundEvent> getEventStreamForTag(String tag);

  Future<void> init();
  void dispose();

  Future<List<BtmTask>> getTasksWithStatus({required List<BtmTaskStatus> status});
  Future<void> executeTask(BtmTask task);
}

class BtmTask {
  /// You can pass your own unique ```Id``` or one will be generated for you
  final String taskId;

  /// Optional. Need not be unique. Just used to categorize a task.
  final String? tag;

  /// This is the function that will execute in the background.
  /// Make sure this is a ```top-level``` or a ```static``` function
  final BackgroundTask handle;

  /// These arguments will be passed to the background ```handle```
  final PlatformArguments args;

  BtmTask({this.tag, required this.handle, String? taskId, this.args}) : taskId = (taskId ?? const Uuid().v4());

  @override
  String toString() {
    return 'BtmTask(taskId: $taskId, tag: $tag, handle: $handle, args: $args)';
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'tag': tag,
      'handle': handle.toRawHandle,
      'args': args?.toRawMap(),
    };
  }

  factory BtmTask.fromMap(Map<dynamic, dynamic> map) {
    final taskId = map['taskId'];
    if (taskId == null || taskId is! String) throw Exception("taskId error for $map");
    final handle = map['handle'] is! int ? null : FunctionExt.fromRawHandle(map['handle']);
    if (handle == null || handle is! Future<void> Function(Object?)) {
      throw HandleNotFoundException(rawHandle: map['handle'], message: "Handle : $handle");
    }
    debugPrint(" BtmTask.fromMap of $taskId args : ${map['args'].runtimeType}");
    return BtmTask(
      taskId: taskId,
      tag: map['tag'] is! String? ? null : map['tag'],
      handle: handle,
      args: map['args'] == null ? null : BackgroundDataFieldMapExt.fromMap(map['args']),
    );
  }

  String toJson() => json.encode(toMap());

  factory BtmTask.fromJson(String source) => BtmTask.fromMap(json.decode(source));
}

class HandleNotFoundException extends Error {
  final String? message;
  final int? rawHandle;
  HandleNotFoundException({
    this.message,
    this.rawHandle,
  });

  @override
  String toString() => 'HandleNotFoundException(message: $message, rawHandle: $rawHandle)';
}
