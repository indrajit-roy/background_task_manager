import 'dart:async';
import 'dart:convert';

import 'package:background_task_manager/background_task_manager.dart';
import 'package:background_task_manager/interfaces/background_task_i.dart';
import 'package:flutter/material.dart';

void main() {
  debugPrint("relaunch debug main");
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("relaunch debug main binding init");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late BtmTask task;
  late Future future;
  @override
  void initState() {
    future = BackgroundTaskManager().init(tasks: {});
    task = BtmTask<TestObject>(
      taskId: "001",
      args: TestObject(data: "I AM ARGUMENTS"),
      type: "test",
      handle: testHandle,
      converter: (map) => TestObject.fromMap(map),
    );
    debugPrint("relaunch debug main app init");
    super.initState();
  }

  @override
  void dispose() {
    BackgroundTaskManager.singleton.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("relaunch debug, app build");
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: FutureBuilder(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              return Center(
                  child: Column(
                children: [
                  StreamBuilder(
                    initialData: "No work is Queued",
                    stream: BackgroundTaskManager.singleton.getEventStreamFor(task.taskId),
                    builder: (context, snapshot) => Text("${snapshot.data}"),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                      onPressed: () {
                        BackgroundTaskManager.singleton.executeTask(task);
                      },
                      child: const Text("Start Task"))
                ],
              ));
            }),
      ),
    );
  }
}

class TestObject extends BackgroundEvent {
  String? data;

  TestObject({
    this.data,
  });

  factory TestObject.fromMap(Map<Object?, Object?> map) => TestObject(data: map["data"] is String ? map["data"] as String : null);
  factory TestObject.fromJson(String str) => TestObject.fromMap(json.decode(str));
  @override
  Map<Object?, Object?> toMap() {
    return {"data": data};
  }

  @override
  String toString() => 'TestObject(data: $data)';
}

Future<void> testHandle(Object args) async {
  TestObject? serializedArgs;
  if (args is String) serializedArgs = TestObject.fromJson(args);
  var i = 12;
  try {
    await Future.doWhile(() async {
      debugPrint("Executing testHandle $i");

      BackgroundTaskManager.postEvent(args: TestObject(data: "args : $serializedArgs, count : $i").toJson());
      await Future.delayed(const Duration(seconds: 1));
      i--;
      // if (i == 6) throw Exception("i is equal to 6");
      return i > 0;
    });
    BackgroundTaskManager.postEvent(args: TestObject(data: "args : $serializedArgs, count : $i").toJson());
    debugPrint("Executing testHandle SUCCESS $i");
  } on Exception catch (e) {
    debugPrint("Executing testHandle FAILURE $i");
    throw e;
  }
}
