import 'dart:async';

import 'package:background_task_manager/interfaces/background_task_i.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';

class BackgroundTaskCache implements BackgroundTaskCacheInterface {
  late Box box;

  @override
  FutureOr<void> init() async {
    try {
      box = await Hive.openBox("BackgroundTaskCache_hive_box");
    } on Exception catch (e) {
      debugPrint("BackgroundTaskCache init exception $e");
      rethrow;
    } on Error catch (e) {
      debugPrint("BackgroundTaskCache init error $e");
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final result = await box.clear();
      debugPrint("BackgroundTaskCache clear result $result");
    } on Exception catch (e) {
      debugPrint("BackgroundTaskCache clear exception $e");
      rethrow;
    } on Error catch (e) {
      debugPrint("BackgroundTaskCache clear error $e");
      rethrow;
    }
  }

  @override
  FutureOr<BackgroundTaskInfo?> get(String taskId) {
    try {
      final value = box.get(taskId);
      if (value == null) return null;
      if (value is! Map<String, dynamic>) throw Exception("Value stored is not of type Map<String,dynamic>. value : $value");
      return BackgroundTaskInfo.fromMap(value);
    } on Exception catch (e) {
      debugPrint("BackgroundTaskCache get exception $e");
      rethrow;
    } on Error catch (e) {
      debugPrint("BackgroundTaskCache get error $e");
      rethrow;
    }
  }

  @override
  FutureOr<List<BackgroundTaskInfo>> getTasks(List<String> taskIds) {
    try {
      List<BackgroundTaskInfo> list = [];
      for (var element in taskIds) {
        final value = box.get(element);
        debugPrint("BackgroundTaskCache getTasks for $element value = $value of type ${value.runtimeType}");
        if (value == null || value is! Map) continue;
        try {
          list.add(BackgroundTaskInfo.fromMap(value));
        } on HandleNotFoundException catch (e) {
          print("Handle not found for $value exception: $e");
        }
      }
      return list;
    } on Exception catch (e) {
      debugPrint("BackgroundTaskCache getTasks exception $e");
      rethrow;
    } on Error catch (e) {
      debugPrint("BackgroundTaskCache getTasks error $e");
      rethrow;
    }
  }

  @override
  FutureOr<List<BackgroundTaskInfo>> getTasksByTag(String tag) {
    List<BackgroundTaskInfo> list = [];
    for (var element in box.values) {
      if (element == null || element is! Map<String, dynamic>) continue;
      list.add(BackgroundTaskInfo.fromMap(element));
    }
    return list;
  }

  @override
  FutureOr<void> put(BackgroundTaskInfo task) async {
    try {
      debugPrint("BackgroundTaskCache put task $task");
      final map = task.toMap();
      debugPrint("BackgroundTaskCache put map $map");
      await box.put(task.taskId, map);
    } on Exception catch (e) {
      debugPrint("BackgroundTaskCache put exception $e");
      rethrow;
    } on Error catch (e) {
      debugPrint("BackgroundTaskCache put error $e");
      rethrow;
    }
  }

  @override
  FutureOr<void> remove(String taskId) async {
    try {
      await box.delete(taskId);
    } on Exception catch (e) {
      debugPrint("BackgroundTaskCache remove exception $e");
      rethrow;
    } on Error catch (e) {
      debugPrint("BackgroundTaskCache remove error $e");
      rethrow;
    }
  }
}

abstract class BackgroundTaskCacheInterface {
  FutureOr<void> init();
  FutureOr<void> put(BackgroundTaskInfo task);
  FutureOr<BackgroundTaskInfo?> get(String taskId);
  FutureOr<List<BackgroundTaskInfo>> getTasks(List<String> taskId);
  FutureOr<List<BackgroundTaskInfo>> getTasksByTag(String tag);
  FutureOr<void> remove(String taskId);
  FutureOr<void> clear();
}
