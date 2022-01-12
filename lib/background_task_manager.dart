import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

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

  BackgroundTaskManager._() : _internalEventStream = StreamController.broadcast();
  factory BackgroundTaskManager() => _instance ??= BackgroundTaskManager._();
  static BackgroundTaskManager? _instance;
  static BackgroundTaskManager get singleton => _instance ??= BackgroundTaskManager();
  // static Map<Type, Function> _converterMap = {};
  // taskId : BtmTask
  late final Map<String, BtmTask> _registeredTasks;

  Stream? _eventStream;
  final StreamController _internalEventStream;
  StreamSubscription? _streamSubscription;

  @override
  Stream get eventStream => _eventStream ??= _eventChannel.receiveBroadcastStream();

  @override
  Stream<T> getEventStream<T extends BackgroundEvent>() {
    throw UnimplementedError();
  }

  @override
  Stream getEventStreamFor(String taskId) {
    try {
      return eventStream.where((event) {
        debugPrint("getEventStreamFor, raw event=$event");
        return event["taskId"] == taskId;
      }).map((event) {
        debugPrint("getEventStreamFor $taskId, raw event=$event");
        return _registeredTasks[taskId]?.converter(json.decode(event["event"])) ?? event;
      });
    } on Exception catch (e) {
      debugPrint("getEventStreamFor exception $e");
      return eventStream;
    } on Error catch (e) {
      debugPrint("getEventStreamFor error $e");
      return eventStream;
    }
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
  Future<void> init({Map<String, BtmTask>? tasks}) async {
    _registeredTasks = tasks ?? {};
    final initValue = await _methodChannel.invokeMethod("initialize");
    debugPrint("BackgroundTaskManager init $initValue");
    _eventStream ??= _eventChannel.receiveBroadcastStream();
    _streamSubscription = _eventStream?.listen((event) {
      _internalEventStream.add(event);
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _internalEventStream.close();
    _streamSubscription = null;
  }
}
