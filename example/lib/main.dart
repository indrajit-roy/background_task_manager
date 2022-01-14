import 'dart:async';
import 'dart:convert';

import 'package:background_task_manager/background_task_manager.dart';
import 'package:background_task_manager/interfaces/background_task_i.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
  debugPrint("relaunch debug main");
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("relaunch debug main binding init");
  runApp(const FlutterApp(child: MyApp()));
}

class FlutterApp extends StatelessWidget {
  final Widget child;
  const FlutterApp({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: child,
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late BtmTask task;
  late Future future;
  String? tasksByStatus;
  String? id;
  final status = BtmTaskStatus.RUNNING;
  bool isInit = false;

  Future<void> init() async {
    future = BackgroundTaskManager().init(
        modelMap: BtmModelMap.mapper()
            .addModel<TestObject>(
              type: "test",
              converter: (map) => TestObject.fromMap(map),
            )
            .buildMap());
    await future;
    try {
      final t = await BackgroundTaskManager.singleton.getTasksWithStatus(status: status);
      tasksByStatus = t.toString();
      if (t.isNotEmpty) {
        id = t.first.taskId;
      }
    } on Exception catch (e) {
      tasksByStatus = e.toString();
    } on Error catch (e) {
      tasksByStatus = e.toString();
    } finally {
      isInit = true;
      setState(() {});
    }
  }

  @override
  void initState() {
    task = BtmTask<TestObject>(
      type: "test",
      args: TestObject(data: "I AM ARGUMENTS"),
      handle: testHandle,
    );
    debugPrint("relaunch debug main app init");
    init();
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
    return Scaffold(
      body: FutureBuilder(
          future: isInit ? null : init(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            return Center(
                child: Column(
              children: [
                Text(
                  "$status : $tasksByStatus",
                  style: TextStyle(color: Colors.white),
                ),
                if (id != null)
                  StreamBuilder(
                    initialData: "No work is Queued",
                    stream: BackgroundTaskManager.singleton.getEventStreamFor(id!),
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
      return i > 0;
    });
    BackgroundTaskManager.postEvent(args: TestObject(data: "args : $serializedArgs, count : $i").toJson());
    debugPrint("Executing testHandle SUCCESS $i");
  } on Exception catch (e) {
    debugPrint("Executing testHandle FAILURE $i");
    throw e;
  }
}
