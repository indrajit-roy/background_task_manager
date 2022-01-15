import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'interfaces/background_task_i.dart';

const _methodChannel = MethodChannel("background_task_manager_method_channel");
const _bgMethodChannel = MethodChannel("background_task_manager_worker_method_channel");
const _progressEventChannel = EventChannel("background_task_manager_event_channel");
const _resultEventChannel = EventChannel("background_task_manager_event_channel_result");

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
          return {"result": StringDataField(value: "success").toMap()};
        } catch (e) {
          throw {"result": StringDataField(value: "Something went exception!").toMap()};
        }
      default:
        null;
    }
  });
}

class BackgroundTaskManager implements BackgroundTaskInterface {
  static postEvent({required Map<String, BackgroundDataField> args}) =>
      _bgMethodChannel.invokeMethod("sendEvent", args.map<String, Map>((key, value) => MapEntry(key, value.toMap())));
  static postSuccess({required Map<String, BackgroundDataField> args}) =>
      _bgMethodChannel.invokeMethod("success", args..map<String, Map>((key, value) => MapEntry(key, value.toMap())));
  static postFailure({required Map<String, BackgroundDataField> args}) =>
      _bgMethodChannel.invokeMethod("failed", args.map<String, Map>((key, value) => MapEntry(key, value.toMap())));

  BackgroundTaskManager._()
      : _internalProgressEventStream = StreamController.broadcast(),
        _internalResultEventStream = StreamController.broadcast();
  static BackgroundTaskManager? _instance;
  static BackgroundTaskManager get singleton => _instance ??= BackgroundTaskManager._();

  Completer<bool> initCompletable = Completer<bool>();
  bool? _isInitialized;
  bool get isInitialized => initCompletable.isCompleted && _isInitialized == true;
  bool get startedInitialization => _isInitialized != null;

  Map<String, String> taskToType = {};

  Stream? _progressEventStream;
  Stream? _resultEventStream;

  final StreamController _internalProgressEventStream;
  final StreamController _internalResultEventStream;
  StreamSubscription? _progressStreamSubscription;
  StreamSubscription? _resultStreamSubscription;

  @override
  Stream get eventStream => _internalProgressEventStream.stream;
  @override
  Stream get resultStream => _internalResultEventStream.stream;

  @override
  Stream<Map> getEventStreamFor(String taskId) => eventStream.where((event) {
        debugPrint("getEventStreamFor, raw event=$event");
        return event["taskId"] == taskId;
      }).map((event) {
        return event["event"];
      });

  @override
  Stream<Map> getResultStreamFor(String taskId) => resultStream.where((event) {
        debugPrint("getEventStreamFor, raw event=$event");
        return event["taskId"] == taskId;
      }).map((event) {
        return event["result"];
      });

  @override
  Future<void> executeTask(BtmTask task) async {
    try {
      debugPrint("executeTask task $task");
      if (!startedInitialization) {
        throw Exception("BackgroundTaskManager initialization not initiated. Please call BackgroundTaskManager.singleton.init()");
      }
      if (!initCompletable.isCompleted) await initCompletable.future;
      if (!isInitialized) throw Exception("BackgroundTaskManager is not initialized.");
      final result = await _methodChannel.invokeMethod("executeTask", {
        "taskId": task.taskId,
        "tag": task.tag,
        "callbackHandle": PluginUtilities.getCallbackHandle(_callbackDispatcher)?.toRawHandle(),
        "taskHandle": PluginUtilities.getCallbackHandle(task.handle)?.toRawHandle(),
        "args": task.args?.map<String, Map>((key, value) => MapEntry(key, value.toMap()))
      });
      debugPrint("executeTask success $result");
    } on Exception catch (e) {
      debugPrint("executeTask Exception $e");
      rethrow;
    }
  }

  @override
  Future<List<BtmTask>> getTasksWithStatus({required BtmTaskStatus status}) async {
    try {
      debugPrint("getTasksWithStatus start $status");
      if (!startedInitialization) {
        throw Exception("BackgroundTaskManager initialization not initiated. Please call BackgroundTaskManager.singleton.init()");
      }
      if (!initCompletable.isCompleted) await initCompletable.future;
      if (!isInitialized) throw Exception("BackgroundTaskManager is not initialized.");
      final taskIds = await _methodChannel.invokeMethod("getTasksByStatus", {"status": status.name});
      debugPrint("getTasksWithStatus got $taskIds of type : ${taskIds.runtimeType}");
      if (taskIds is List) {
        // TODO : Retrieve task info from cache and map Ids to Tasks
        return taskIds.map((e) => BtmTask(taskId: e, handle: (obj) async {})).toList();
      }
      return <BtmTask>[];
    } on Exception catch (e) {
      debugPrint("BackgroundTaskManager getTasksWithStatus exception $e");
      rethrow;
    }
  }

  @override
  Future<void> init() async {
    try {
      debugPrint("BackgroundTaskManager init start");
      _isInitialized = false;
      final initValue = await _methodChannel.invokeMethod("initialize");
      //* Initialize progress Stream
      _progressEventStream ??= _progressEventChannel.receiveBroadcastStream();
      _progressStreamSubscription = _progressEventStream?.listen((event) {
        _internalProgressEventStream.add(event);
      });
      //* Initialize result Stream
      _resultEventStream ??= _resultEventChannel.receiveBroadcastStream();
      _resultStreamSubscription = _resultEventStream?.listen((event) {
        _internalResultEventStream.add(event);
      });
      _isInitialized = initValue;
      initCompletable.complete(_isInitialized);
      debugPrint("BackgroundTaskManager init success");
    } on Exception catch (e) {
      debugPrint("BackgroundTaskManager init exception $e");
      initCompletable.complete(false);
      rethrow;
    } on Error catch (e) {
      debugPrint("BackgroundTaskManager init error $e");
      initCompletable.complete(false);
      rethrow;
    }
  }

  @override
  void dispose() {
    _progressStreamSubscription?.cancel();
    _resultStreamSubscription?.cancel();
    _internalProgressEventStream.close();
    _internalResultEventStream.close();
    _progressStreamSubscription = null;
    _resultStreamSubscription = null;
  }
}
