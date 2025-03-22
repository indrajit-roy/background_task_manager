# background_task_manager

A plugin that facilitates background work in Flutter. Supports backward communication with the main thread, which is something that is missing in the official plugin.

## Getting Started

```dart
Future<PlatformArguments> handler(obj) async {
  final list = List.generate(obj["length"], (index) => index);
  await Future.forEach<int>(list, (element) async {
    await Future.delayed(const Duration(seconds: 1));
    BackgroundTaskManager.postEvent(args: {"key": StringDataField(value: "Event from background thread!")});
  });

  return {"result": StringDataField(value: "I am result the result after the work is done!")};
}

final task = await BackgroundTaskManager.singleton.executeTask(handler, args: {"length": IntegerDataField(value: 9000)}, tag: "tag1");
BackgroundTaskManager.singleton.getEventStreamForTask(task.taskId).listen((event) {
  print(event)
});
```

