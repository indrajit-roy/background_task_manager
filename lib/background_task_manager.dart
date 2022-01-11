import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'interfaces/background_task_i.dart';

const _methodChannel = MethodChannel("background_task_manager_method_channel");
const _bgMethodChannel = MethodChannel("background_task_manager_worker_method_channel");
const _eventChannel = EventChannel("background_task_manager_event_channel");

void _callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  _bgMethodChannel.setMethodCallHandler((call) async {
    debugPrint("Callback Dispatcher Method Called ${call.method}");
    switch (call.method) {
      case "executeCallback":
        final argsMap = (call.arguments as Map);
        final CallbackHandle handle = CallbackHandle.fromRawHandle(argsMap["taskHandle"]);
        final Function? closure = PluginUtilities.getCallbackFromHandle(handle);
        if (closure == null) {
          debugPrint('Fatal: could not find user callback');
          _bgMethodChannel.invokeMethod("failure");
          exit(-1);
        }
        try {
          await closure(argsMap["args"]);
          await Future.delayed(const Duration(milliseconds: 200));
          return "success";
        } catch (e) {
          throw e.toString();
        }
      default:
        null;
    }
  });
}

class BackgroundTaskManager implements BackgroundTaskInterface {
  static postSuccess({String? data}) => _bgMethodChannel.invokeMethod("success", data);
  static postFailure({String? exceptionMessage}) => _bgMethodChannel.invokeMethod("failed", exceptionMessage);
  static postEvent({String? args}) => _bgMethodChannel.invokeMethod("sendEvent", args);

  BackgroundTaskManager._(Map<String, BtmTask>? tasks) : _registeredTasks = tasks ?? {} {
    _eventStream = _eventChannel.receiveBroadcastStream();
  }

  static BackgroundTaskManager? _instance;
  static BackgroundTaskManager? get singleton => _instance;
  static Map<Type, Function> _converterMap = {};
  // taskId : BtmTask
  final Map<String, BtmTask> _registeredTasks;

  factory BackgroundTaskManager({Map<String, BtmTask>? tasks = const {}}) => _instance ??= BackgroundTaskManager._(tasks);

  late Stream _eventStream;

  @override
  Stream get eventStream => _eventStream;

  @override
  Stream<T> getEventStream<T extends BackgroundEvent>() {
    throw UnimplementedError();
  }

  @override
  Stream getEventStreamFor(String taskId) {
    return eventStream.where((event) => event["taskId"] == taskId).map((event) => _registeredTasks[taskId]?.converter(json.decode(event["event"])));
  }

  @override
  Future<void> executeTask<T extends BackgroundEvent>(BtmTask<T> task) async {
    try {
      debugPrint("executeTask task $task");
      final result = await _methodChannel.invokeMethod("executeTask", {
        "taskId": task.taskId,
        "callbackHandle": PluginUtilities.getCallbackHandle(_callbackDispatcher)?.toRawHandle(),
        "taskHandle": PluginUtilities.getCallbackHandle(task.handle)?.toRawHandle(),
        "args": task.args?.toJson()
      });
      _registeredTasks[task.taskId] = task;
      debugPrint("executeTask success $result");
    } on Exception catch (e) {
      debugPrint("executeTask Exception $e");
      rethrow;
    }
  }

  @override
  Future<bool> isServiceRunning() {
    throw UnimplementedError();
  }

  @override
  Future<void> startForegroundService() {
    throw UnimplementedError();
  }

  @override
  Future<void> stopForegroundService() {
    throw UnimplementedError();
  }
}
