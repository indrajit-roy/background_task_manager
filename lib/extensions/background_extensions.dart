import 'dart:ui';

import '../background_task_manager.dart';

extension BackgroundDataFieldMapExt on Map<String, BackgroundDataField> {
  Map<String, Map> toRawMap() => map<String, Map<String, dynamic>>((key, value) => MapEntry(key, value.toMap()));

  static Map<String, BackgroundDataField> fromMap(Map<dynamic, dynamic> map) =>
      map.map<String, BackgroundDataField>((key, value) => MapEntry(key, BackgroundDataField.fromMap(value)));
}

extension FunctionExt on Function {
  int? get toRawHandle => PluginUtilities.getCallbackHandle(this)?.toRawHandle();
  static Function? fromRawHandle(int rawHandle) => PluginUtilities.getCallbackFromHandle(CallbackHandle.fromRawHandle(rawHandle));
}
