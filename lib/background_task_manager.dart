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
        BackgroundTask? closure;
        try {
          closure = PluginUtilities.getCallbackFromHandle(handle) as BackgroundTask?;
        } on Error catch (e) {
          print("closure is of type ${closure.runtimeType}. Error $e");
        }
        if (closure == null) {
          debugPrint('Fatal: could not find user callback');
          _bgMethodChannel.invokeMethod("failure");
          exit(-1);
        }
        try {
          print("_callbackDispatcher argsMap : $argsMap");
          final result = await closure(argsMap["args"]);
          print("_callbackDispatcher result : $result");
          await Future.delayed(const Duration(milliseconds: 200));
          return result?.toRawMap();
        } on Exception catch (e) {
          debugPrint("_callbackDispatcher exception $e");
          await Future.delayed(const Duration(milliseconds: 200));
          throw {"result": StringDataField(value: "Task could not be executed. Exception $e").toMap()};
        } on Error catch (e) {
          debugPrint("_callbackDispatcher exception $e");
          await Future.delayed(const Duration(milliseconds: 200));
          throw {"result": StringDataField(value: "Task could not be executed. Error $e").toMap()};
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
  final taskStreamMap = <String, BehaviorSubject<BackgroundEvent>>{};

  Stream get _progressStream {
    //* Initialize progress Stream if not already initialized
    _progressEventStream ??= _progressEventChannel.receiveBroadcastStream();
    _progressStreamSubscription ??= _progressEventStream?.listen((event) {
      _internalProgressEventStream.add(event);
    });
    return _internalProgressEventStream.stream;
  }

  Stream get _resultStream => _internalResultEventStream.stream;

  @override
  Stream<BackgroundEvent> getEventStreamForTask(String id) {
    return taskStreamMap[id] ??= BehaviorSubject()
      ..addStream(Rx.merge([_progressStream, _resultStream]).where((event) => event["taskId"] == id).map((event) => BackgroundEvent.fromMap(event)));
  }

  @override
  Stream<BackgroundEvent> getEventStreamForTag(String tag) =>
      Rx.merge([_progressStream, _resultStream]).map((event) => BackgroundEvent.fromMap(event)).where((event) => event.tag == tag);

  @override
  Future<BackgroundTaskInfo> executeTask(BackgroundTask taskCallback, {PlatformArguments args, String? tag}) async {
    try {
      if (!_startedInitialization) {
        throw Exception("BackgroundTaskManager initialization not initiated. Please call BackgroundTaskManager.singleton.init()");
      }

      if (!initCompletable.isCompleted) await initCompletable.future;
      if (!isInitialized) throw Exception("BackgroundTaskManager is not initialized.");
      final result = await _methodChannel.invokeMethod("executeTask",
          {"tag": tag, "callbackHandle": _callbackDispatcher.toRawHandle, "taskHandle": taskCallback.toRawHandle, "args": args?.toRawMap()});
      BackgroundTaskInfo? task;
      if (result is Map) {
        task = BackgroundTaskInfo.fromMap(result
          ..addEntries([
            MapEntry("handle", taskCallback.toRawHandle),
            MapEntry("args", args?.toRawMap()),
          ]));
        await cache.put(task);
      }
      debugPrint("executeTask success $result");
      if (task == null) throw Exception("Task is Null. Something went wrong. Platform result : $result, task : $task");
      return task;
    } on Exception catch (e) {
      debugPrint("executeTask Exception $e");
      rethrow;
    } on Error catch (e) {
      debugPrint("executeTask Error $e");
      rethrow;
    }
  }

  @override
  Future<List<BackgroundTaskInfo>> getTasksWithStatus({required List<BtmTaskStatus> status}) async {
    try {
      debugPrint("getTasksWithStatus start $status");
      if (!_startedInitialization) {
        throw Exception("BackgroundTaskManager initialization not initiated. Please call BackgroundTaskManager.singleton.init()");
      }
      if (!initCompletable.isCompleted) await initCompletable.future;
      if (!isInitialized) throw Exception("BackgroundTaskManager is not initialized.");
      final workInfos = await _methodChannel.invokeMethod<List>("getTasksByStatus", {"status": status.map((e) => e.name).toList()});
      debugPrint("getTasksWithStatus got $workInfos of type : ${workInfos.runtimeType}");
      final idList = <String>[];
      workInfos?.forEach((element) {
        debugPrint("getTasksWithStatus $element type : ${element.runtimeType}");
        if (element is Map) idList.add(element["taskId"]);
      });
      debugPrint("getTasksWithStatus idList : $idList");
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
      debugPrint("BackgroundTaskManager init start $isInitialized");
      if (isInitialized == true) return;
      if (_startedInitialization) return;
      _isInitialized = false;
      //* Initialize result Stream
      _resultEventStream ??= _resultEventChannel.receiveBroadcastStream();
      _resultStreamSubscription = _resultEventStream?.listen((event) {
        print("Result Stream on init : $event");
        print("Result Stream on init, Background Event : ${BackgroundEvent.fromMap(event)}");
        _internalResultEventStream.add(event);
      });
      final initValue = await _methodChannel.invokeMethod("initialize");
      if (initValue is bool) {
        _isInitialized = initValue;
      }
      if (_isInitialized != true) throw Exception("Failed");
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
    for (var element in taskStreamMap.values) {
      element.close();
    }
    _progressEventStream = null;
    _resultEventStream = null;
    _progressStreamSubscription = null;
    _resultStreamSubscription = null;
    initCompletable = Completer<bool>();
    _isInitialized = false;
  }

  @override
  Future<BackgroundTaskInfo> enqueueUniqueTask(BackgroundTask taskCallback, String uniqueWorkName, {PlatformArguments? args, String? tag}) async {
    try {
      if (!_startedInitialization) {
        throw Exception("BackgroundTaskManager initialization not initiated. Please call BackgroundTaskManager.singleton.init()");
      }

      if (!initCompletable.isCompleted) await initCompletable.future;
      if (!isInitialized) throw Exception("BackgroundTaskManager is not initialized.");
      final result = await _methodChannel.invokeMethod("enqueueUniqueTask", {
        "tag": tag,
        "callbackHandle": _callbackDispatcher.toRawHandle,
        "taskHandle": taskCallback.toRawHandle,
        "uniqueWorkName": uniqueWorkName,
        "args": args?.toRawMap()
      });
      BackgroundTaskInfo? task;
      if (result is Map) {
        task = BackgroundTaskInfo.fromMap(result
          ..addEntries([
            MapEntry("handle", taskCallback.toRawHandle),
            MapEntry("args", args?.toRawMap()),
          ]));
        await cache.put(task);
      }
      debugPrint("executeTask success $result");
      if (task == null) throw Exception("Task is Null. Something went wrong. Platform result : $result, task : $task");
      return task;
    } on Exception catch (e) {
      debugPrint("executeTask Exception $e");
      rethrow;
    } on Error catch (e) {
      debugPrint("executeTask Error $e");
      rethrow;
    }
  }

  @override
  Future<List<BackgroundTaskInfo>> getTasksWithTag(String tag) async {
    if (!_startedInitialization) {
      throw Exception("BackgroundTaskManager initialization not initiated. Please call BackgroundTaskManager.singleton.init()");
    }
    if (!initCompletable.isCompleted) await initCompletable.future;
    if (!isInitialized) throw Exception("BackgroundTaskManager is not initialized.");
    final tasksWithTag = <BackgroundTaskInfo>[];
    final tasks = await _methodChannel.invokeMethod<List>("getTasksWithTag", {"tag": tag});
    if (tasks is List) {
      final idList = <String>[];
      for (var e in tasks) {
        if (e is! Map) continue;
        final s = e["taskId"];
        if (s is String) idList.add(s);
      }
      return await cache.getTasks(idList);
    }
    return tasksWithTag;
  }

  @override
  Future<List<BackgroundTaskInfo>> getTasksWithUniqueWorkName(String uniqueWorkName) async {
    if (!_startedInitialization) {
      throw Exception("BackgroundTaskManager initialization not initiated. Please call BackgroundTaskManager.singleton.init()");
    }
    if (!initCompletable.isCompleted) await initCompletable.future;
    if (!isInitialized) throw Exception("BackgroundTaskManager is not initialized.");
    final tasksWithTag = <BackgroundTaskInfo>[];
    final tasks = await _methodChannel.invokeMethod<List>("getTasksWithUniqueWorkName", {"uniqueWorkName": uniqueWorkName});
    if (tasks is List) {
      final idList = <String>[];
      for (var e in tasks) {
        if (e is! Map) continue;
        final s = e["taskId"];
        if (s is String) idList.add(s);
      }
      return await cache.getTasks(idList);
    }
    return tasksWithTag;
  }
}
