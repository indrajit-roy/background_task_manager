import 'dart:async';
import 'dart:convert';

import 'package:background_task_manager/background_task_manager.dart';
import 'package:background_task_manager/interfaces/background_task_i.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late BtmTask task;
  @override
  void initState() {
    task = BtmTask<TestObject>(
      args: TestObject(data: "I AM ARGUMENTS"),
      type: "test",
      handle: testHandle,
      converter: (map) => TestObject.fromMap(map),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
            child: Column(
          children: [
            StreamBuilder(
              initialData: "No work is Queued",
              stream: BackgroundTaskManager(tasks: {}).getEventStreamFor(task.taskId),
              builder: (context, snapshot) => Text("${snapshot.data}"),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: () {
                  BackgroundTaskManager.singleton?.executeTask(task);
                },
                child: const Text("Start Task"))
          ],
        )),
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
  var i = 10;
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
