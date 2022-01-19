import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:background_task_manager/cache/background_task_cache.dart';
import 'package:background_task_manager/extensions/background_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'interfaces/background_task_i.dart';
import 'models/background_data_field.dart';
import 'models/background_event.dart';

export 'models/background_data_field.dart';

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
          print("_callbackDispatcher argsMap : $argsMap");
          await closure(argsMap["args"]);
          await Future.delayed(const Duration(milliseconds: 200));
          return {"result": StringDataField(value: "success").toMap()};
        } catch (e) {
          await Future.delayed(const Duration(milliseconds: 200));
          throw {"result": StringDataField(value: "Task could not be executed. $e").toMap()};
        }
      default:
        null;
    }
  });
}

class BackgroundTaskManager implements BackgroundTaskInterface {
  static postEvent({required Map<String, BackgroundDataField> args}) => _bgMethodChannel.invokeMethod("sendEvent", args.toRawMap());

  BackgroundTaskManager._()
      : _internalProgressEventStream = StreamController.broadcast(),
        _internalResultEventStream = StreamController.broadcast();
  static BackgroundTaskManager? _instance;
  static BackgroundTaskManager get singleton => _instance ??= BackgroundTaskManager._();

  Completer<bool> initCompletable = Completer<bool>();
  bool? _isInitialized;
  bool get isInitialized => initCompletable.isCompleted && _isInitialized == true;
  bool get _startedInitialization => _isInitialized != null;

  Map<String, String> taskToType = {};

  Stream? _progressEventStream;
  Stream? _resultEventStream;

  final StreamController _internalProgressEventStream;
  final StreamController _internalResultEventStream;
  StreamSubscription? _progressStreamSubscription;
  StreamSubscription? _resultStreamSubscription;

  final cache = BackgroundTaskCache();

  Stream get _progressStream => _internalProgressEventStream.stream;
  Stream get _resultStream => _internalResultEventStream.stream;

  Stream<BackgroundEvent> getEventStreamFor(String taskId) => Rx.merge<BackgroundEvent>([getProgressStreamFor(taskId), getResultStreamFor(taskId)]);

  @override
  Stream<BackgroundEvent> getProgressStreamFor(String taskId) => _progressStream.where((event) {
        debugPrint("getEventStreamFor, raw event=$event");
        return event["taskId"] == taskId;
      }).map<BackgroundEvent>((event) => BackgroundEvent.fromMap(event));

  @override
  Stream<BackgroundEvent> getResultStreamFor(String taskId) => _resultStream.where((event) {
        debugPrint("getResultStreamFor, raw event=$event");
        return event["taskId"] == taskId;
      }).map<BackgroundEvent>((event) => BackgroundEvent.fromMap(event));

  @override
  Stream<BackgroundEvent> getEventStreamForTag(String tag) =>
      Rx.merge([_progressStream, _resultStream]).map((event) => BackgroundEvent.fromMap(event)).where((event) => event.tag == tag);

  @override
  Future<void> executeTask(BtmTask task) async {
    try {
      debugPrint("executeTask task $task");
      if (!_startedInitialization) {
        throw Exception("BackgroundTaskManager initialization not initiated. Please call BackgroundTaskManager.singleton.init()");
      }

      if (!initCompletable.isCompleted) await initCompletable.future;
      if (!isInitialized) throw Exception("BackgroundTaskManager is not initialized.");
      final result = await _methodChannel.invokeMethod("executeTask", {
        "taskId": task.taskId,
        "tag": task.tag,
        "callbackHandle": _callbackDispatcher.toRawHandle,
        "taskHandle": task.handle.toRawHandle,
        "args": task.args?.toRawMap()
      });
      await cache.put(task);
      debugPrint("executeTask success $result");
    } on Exception catch (e) {
      debugPrint("executeTask Exception $e");
      rethrow;
    } on Error catch (e) {
      debugPrint("executeTask Error $e");
      rethrow;
    }
  }

  @override
  Future<List<BtmTask>> getTasksWithStatus({required List<BtmTaskStatus> status}) async {
    try {
      debugPrint("getTasksWithStatus start $status");
      if (!_startedInitialization) {
        throw Exception("BackgroundTaskManager initialization not initiated. Please call BackgroundTaskManager.singleton.init()");
      }
      if (!initCompletable.isCompleted) await initCompletable.future;
      if (!isInitialized) throw Exception("BackgroundTaskManager is not initialized.");
      final taskIds = await _methodChannel.invokeMethod<List>("getTasksByStatus", {"status": status.map((e) => e.name).toList()});
      debugPrint("getTasksWithStatus got $taskIds of type : ${taskIds.runtimeType}");
      final idList = <String>[];
      taskIds?.forEach((element) {
        debugPrint("getTasksWithStatus $element type : ${element.runtimeType}");
        if (element is String) idList.add(element);
      });
      return await cache.getTasks(idList);
    } on Exception catch (e) {
      debugPrint("BackgroundTaskManager getTasksWithStatus exception $e");
      rethrow;
    }
  }

  @mustCallSuper
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
      final appDocDir = await getApplicationDocumentsDirectory();
      Hive.init(appDocDir.path);
      await cache.init();
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

  @mustCallSuper
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
