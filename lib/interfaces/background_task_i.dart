import 'dart:convert';

import 'package:background_task_manager/models/background_event.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import 'package:background_task_manager/extensions/background_extensions.dart';

import '../models/background_data_field.dart';

typedef BackgroundTask = Future<PlatformArguments> Function(Object? message);
typedef PlatformArguments = Map<String, BackgroundDataField>?;
// ignore: constant_identifier_names
enum BtmTaskStatus { RUNNING, ENQUEUED, BLOCKED, CANCELLED, FAILED, SUCCEEDED }

abstract class BackgroundTaskInterface {
  Stream<BackgroundEvent> getEventStreamForTask(String id);
  Stream<BackgroundEvent> getEventStreamForTag(String tag);

  Future<void> init();
  void dispose();
  
  Future<List<BackgroundTaskInfo>> getTasksWithStatus({required List<BtmTaskStatus> status});
  Future<BackgroundTaskInfo> executeTask(BackgroundTask taskCallback, {PlatformArguments args, String? tag});
  Future<BackgroundTaskInfo> enqueueUniqueTask(BackgroundTask taskCallback, String uniqueWorkName, {PlatformArguments args, String? tag});
  Future<List<BackgroundTaskInfo>> getTasksWithTag(String tag);
  Future<List<BackgroundTaskInfo>> getTasksWithUniqueWorkName(String uniqueWorkName);
}

class BackgroundTaskInfo {
  /// You can pass your own unique ```Id``` or one will be generated for you
  final String taskId;

  /// Optional. Need not be unique. Just used to categorize a task.
  final String? tag;

  /// This is the function that will execute in the background.
  /// Make sure this is a ```top-level``` or a ```static``` function
  final BackgroundTask handle;

  /// These arguments will be passed to the background ```handle```
  final PlatformArguments args;

  BackgroundTaskInfo({this.tag, required this.handle, required this.taskId, this.args});

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

  factory BackgroundTaskInfo.fromMap(Map<dynamic, dynamic> map) {
    final taskId = map['taskId'];
    if (taskId == null || taskId is! String) throw Exception("taskId error for $map");
    final handle = FunctionExt.fromRawHandle(map['handle']);
    if (handle == null || handle is! BackgroundTask) {
      throw HandleNotFoundException(rawHandle: map['handle'], message: "Handle : $handle");
    }
    debugPrint(" BtmTask.fromMap of $taskId args : ${map['args'].runtimeType}");
    return BackgroundTaskInfo(
      taskId: taskId,
      tag: map['tag'] is! String? ? null : map['tag'],
      handle: handle,
      args: map['args'] == null ? null : BackgroundDataFieldMapExt.fromMap(map['args']),
    );
  }

  String toJson() => json.encode(toMap());

  factory BackgroundTaskInfo.fromJson(String source) => BackgroundTaskInfo.fromMap(json.decode(source));
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
