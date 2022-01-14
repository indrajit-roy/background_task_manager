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

  bool _isPlatformInitialized = false;
  bool get isInitialized => _isPlatformInitialized && _eventStream != null;

  late final BtmModelMap _modelMap;
  BtmModelMap get modelMap => _modelMap;
  Map<String, String> taskToType = {};

  Stream? _eventStream;
  final StreamController _internalEventStream;
  StreamSubscription? _streamSubscription;

  @override
  Stream get eventStream => _internalEventStream.stream;

  @override
  Stream<T> getEventStream<T extends BackgroundEvent>() {
    return eventStream.where((event) => _modelMap.getTypeKey<T>() != null).map<T>((event) => _modelMap.getObject<T>(map: event["event"]));
  }

  @override
  Stream getEventStreamFor(String taskId) {
    try {
      return eventStream.where((event) {
        debugPrint("getEventStreamFor, raw event=$event");
        return event["taskId"] == taskId;
      }).map((event) {
        debugPrint("getEventStreamFor $taskId, eventType=${event["event"].runtimeType} modelMap : $_modelMap");
        if (event["type"] != null && event["event"] is String) {
          final model = _modelMap.getObjectFromKey(type: event["type"], map: json.decode(event["event"]));
          debugPrint("getEventStreamFor model : $model of type ${model.runtimeType}");
          return model;
        } else {
          return null;
        }
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
      taskToType[task.taskId] = task.type;
      final result = await _methodChannel.invokeMethod("executeTask", {
        "taskId": task.taskId,
        "tag": task.tag,
        "type": task.type,
        "callbackHandle": PluginUtilities.getCallbackHandle(_callbackDispatcher)?.toRawHandle(),
        "taskHandle": PluginUtilities.getCallbackHandle(task.handle)?.toRawHandle(),
        "args": task.args?.toJson()
      });
      debugPrint("executeTask success $result");
    } on Exception catch (e) {
      debugPrint("executeTask Exception $e");
      rethrow;
    }
  }

  @override
  Future<List<BtmTask<BackgroundEvent>>> getTasksWithStatus({required BtmTaskStatus status}) async {
    try {
      final taskIds = await _methodChannel.invokeMethod("getTasksByStatus", {"status": status.name});
      debugPrint("getTasksWithStatus got $taskIds of type : ${taskIds.runtimeType}");
      if (taskIds is List) {
        // TODO : Retrieve task info from cache and map Ids to Tasks
        return taskIds.map((e) => BtmTask(taskId: e, type: "type", handle: (obj) async {})).toList();
      }
      return <BtmTask<BackgroundEvent>>[];
    } on Exception catch (e) {
      debugPrint("BackgroundTaskManager getTasksWithStatus exception $e");
      rethrow;
    }
  }

  @override
  Future<void> init({BtmModelMap? modelMap}) async {
    try {
      debugPrint("BackgroundTaskManager init start");
      _modelMap = modelMap ??= BtmModelMap.empty();
      final initValue = await _methodChannel.invokeMethod("initialize");
      _isPlatformInitialized = initValue;
      debugPrint("BackgroundTaskManager init $initValue");
      _eventStream ??= _eventChannel.receiveBroadcastStream();
      _streamSubscription = _eventStream?.listen((event) {
        _internalEventStream.add(event);
      });
      debugPrint(
          "BackgroundTaskManager init success _eventStream : $_eventStream, _internalEventStream : $_internalEventStream, _streamSubscription : $_streamSubscription");
    } on Exception catch (e) {
      debugPrint("BackgroundTaskManager init exception $e");
      rethrow;
    } on Error catch (e) {
      debugPrint("BackgroundTaskManager init error $e");
      rethrow;
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _internalEventStream.close();
    _streamSubscription = null;
  }
}
