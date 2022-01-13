import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

typedef BackgroundTask = Future<void> Function(Object message);
// ignore: constant_identifier_names
enum BtmTaskStatus { RUNNING, ENQUEUED, BLOCKED, CANCELLED, FAILED, SUCCEEDED }

abstract class BackgroundTaskInterface {
  Stream get eventStream;
  Stream getEventStreamFor(String taskId);
  Stream<T> getEventStream<T extends BackgroundEvent>();

  Future<void> init();
  void dispose();

  Future<List<BtmTask>> getTasksWithStatus({required BtmTaskStatus status});
  Future<void> executeTask<T extends BackgroundEvent>(BtmTask<T> task);
}

class BtmTask<T extends BackgroundEvent> {
  /// You can pass your own unique ```Id``` or one will be generated for you
  final String taskId;

  /// Optional. Need not be unique. Just used to categorize a task.
  final String? tag;

  /// This is used to derive which ```Type``` of object is sent as background events
  /// from the task. Register the ```Type``` against ```type``` in
  /// ```
  /// BackgroundTaskManager.singleton.init(modelMap : BtmModelMap.mapper().addModel<T>(type,converter).build())
  /// ```
  final String type;

  /// This is the function that will execute in the background.
  /// Make sure this is a ```top-level``` or a ```static``` function
  final BackgroundTask handle;

  /// Make sure you have registered the type ```T``` in ```BtmModelMap``` when calling
  /// ```
  /// BackgroundTaskManager.singleton.init(modelMap : BtmModelMap.mapper().addModel<T>(type,converter).build())
  /// ```
  final T? args;

  BtmTask({this.tag, required this.type, required this.handle, String? taskId, this.args}) : taskId = (taskId ?? const Uuid().v4());

  @override
  String toString() {
    return 'BtmTask(taskId: $taskId, tag: $tag, type: $type, handle: $handle, args: $args)';
  }
}

class BtmModelMap {
  final Map<String, Type> map;
  final Map<Type, Function(Map<Object?, Object?>)> converterMap;
  BtmModelMap._internal(this.map, this.converterMap);

  static BtmModelMapper mapper() => BtmModelMapper();

  Object? getModelFromMap({required String type, required Map<Object?, Object?> map}) {
    if (this.map[type] == null) return null;
    final converterFunction = converterMap[this.map[type]];
    return converterFunction?.call(map);
  }

  String? getTypeKey<T>() {
    try {
      return map.entries.firstWhere((element) => element.value is T).key;
    } on Error catch (e) {
      debugPrint("getTypeKey not found $e");
      return null;
    }
  }

  T getObject<T>({required Map<Object?, Object?> map}) {
    try {
      final obj = converterMap[T]?.call(map);
      if (obj == null) throw Error();
      return obj;
    } on Error catch (e) {
      debugPrint("getObject error $e");
      rethrow;
    }
  }
}

class BtmModelMapper {
  final _map = <String, Type>{};
  final _converterMap = <Type, Function(Map<Object?, Object?> map)>{};

  BtmModelMap buildMap() => BtmModelMap._internal(_map, _converterMap);

  BtmModelMapper addModel<T extends BackgroundEvent>({required String type, required T Function(Map<Object?, Object?> map) converter}) {
    _map.putIfAbsent(type, () => T);
    _converterMap.putIfAbsent(T, () => converter);
    return this;
  }
}

abstract class BackgroundEvent {
  Map<Object?, Object?> toMap();
  String toJson() => json.encode(toMap());
}
