import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

typedef BackgroundTask = Future<void> Function(Object message);

abstract class BackgroundTaskInterface {
  Stream get eventStream;
  Stream getEventStreamFor(String taskId);
  Stream<T> getEventStream<T extends BackgroundEvent>();

  Future<void> init();
  void dispose();

  Future<void> executeTask<T extends BackgroundEvent>(BtmTask<T> task);
}

class BtmTask<T extends BackgroundEvent> {
  final String taskId;
  final String? tag;
  final String type;
  final BackgroundTask handle;
  final T? args;

  BtmTask({this.tag, required this.type, required this.handle, String? taskId, this.args}) : taskId = (taskId ?? const Uuid().v4());

  @override
  String toString() {
    return 'BtmTask(taskId: $taskId, type: $type, handle: $handle, args: $args)';
  }
}

class BtmModelMap {
  final Map<String, Type> map;
  final Map<Type, Function(Map<Object?, Object?>)> converterMap;
  BtmModelMap._internal(this.map, this.converterMap);

  dynamic getModelFromMap({required String type, required Map<Object?, Object?> map}) {
    debugPrint("getModelFromMap type : ${this.map[type]} equal check ${this.map[type] is BackgroundEvent}");
    if (this.map[type] == null) return null;
    final converterFunction = converterMap[this.map[type]];
    debugPrint("getModelFromMap converter : $converterFunction");
    debugPrint("getModelFromMap converterMap : ${converterMap.entries}");
    debugPrint("getModelFromMap input map : $map of type ${map.runtimeType}");
    return converterFunction?.call(map);
  }

  static BtmModelMapper mapper() => BtmModelMapper();
}

class BtmModelMapper {
  final _map = <String, Type>{};
  final _converterMap = <Type, Function(Map<Object?, Object?> map)>{};

  BtmModelMapper addModel<T extends BackgroundEvent>({required String type, required T Function(Map<Object?, Object?> map) converter}) {
    _map.putIfAbsent(type, () => T);
    _converterMap.putIfAbsent(T, () => converter);
    return this;
  }

  BtmModelMap buildMap() => BtmModelMap._internal(_map, _converterMap);
}

abstract class BackgroundEvent {
  Map<Object?, Object?> toMap();
  String toJson() => json.encode(toMap());
}
