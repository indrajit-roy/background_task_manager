import 'package:uuid/uuid.dart';

typedef BackgroundTask = Future<void> Function(Object message);
// ignore: constant_identifier_names
enum BtmTaskStatus { RUNNING, ENQUEUED, BLOCKED, CANCELLED, FAILED, SUCCEEDED }

abstract class BackgroundTaskInterface {
  Stream get eventStream;
  Stream get resultStream;
  Stream getEventStreamFor(String taskId);
  Stream getResultStreamFor(String taskId);

  Future<void> init();
  void dispose();

  Future<List<BtmTask>> getTasksWithStatus({required BtmTaskStatus status});
  Future<void> executeTask(BtmTask task);
}

class BtmTask {
  /// You can pass your own unique ```Id``` or one will be generated for you
  final String taskId;

  /// Optional. Need not be unique. Just used to categorize a task.
  final String? tag;

  // /// This is used to derive which ```Type``` of object is sent as background events
  // /// from the task. Register the ```Type``` against ```type``` in
  // /// ```
  // /// BackgroundTaskManager.singleton.init(modelMap : BtmModelMap.mapper().addModel<T>(type,converter).build())
  // /// ```
  // final String type;

  /// This is the function that will execute in the background.
  /// Make sure this is a ```top-level``` or a ```static``` function
  final BackgroundTask handle;

  /// Make sure you have registered the type ```T``` in ```BtmModelMap``` when calling
  /// ```
  /// BackgroundTaskManager.singleton.init(modelMap : BtmModelMap.mapper().addModel<T>(type,converter).build())
  /// ```
  final dynamic args;

  BtmTask({this.tag, required this.handle, String? taskId, this.args}) : taskId = (taskId ?? const Uuid().v4());

  @override
  String toString() {
    return 'BtmTask(taskId: $taskId, tag: $tag, handle: $handle, args: $args)';
  }
}

abstract class BackgroundDataField<T> {
  String get platformKey;
  T get value;

  Map<String, dynamic> toMap() => {"platformKey": platformKey, "value": value};
}

class IntegerDataField extends BackgroundDataField<int> {
  @override
  final int value;

  IntegerDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "int";
}

class DoubleDataField extends BackgroundDataField<double> {
  @override
  final double value;

  DoubleDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "double";
}

class BooleanDataField extends BackgroundDataField<bool> {
  @override
  final bool value;

  BooleanDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "bool";
}

class StringDataField extends BackgroundDataField<String> {
  @override
  final String value;

  StringDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "String";
}

class StringListDataField extends BackgroundDataField<List<String>> {
  @override
  final List<String> value;

  StringListDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "List<String>";
}

class IntegerListDataField extends BackgroundDataField<List<int>> {
  @override
  final List<int> value;

  IntegerListDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "List<int>";
}

class DoubleListDataField extends BackgroundDataField<List<double>> {
  @override
  final List<double> value;

  DoubleListDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "List<double>";
}

class BooleanListDataField extends BackgroundDataField<List<bool>> {
  @override
  final List<bool> value;

  BooleanListDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "List<bool>";
}
