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
  final streamC = StreamController.broadcast();

  Future<void> init() async {
    future = BackgroundTaskManager.singleton.init();
    await future;
    try {
      final t = await BackgroundTaskManager.singleton.getTasksWithStatus(status: status);
      tasksByStatus = t.toString();
      if (t.isNotEmpty) {
        id = t.first.taskId;
        BackgroundTaskManager.singleton.getEventStreamFor(id!).listen((event) {
          streamC.add(event);
        });
        BackgroundTaskManager.singleton.getResultStreamFor(id!).listen((event) {
          debugPrint("result stream $event");
          streamC.add(event);
        });
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
    task = BtmTask(
      args: {"stringKey": StringDataField(value: "Helloooooo Argssssssss")},
      handle: testHandle,
    );
    debugPrint("relaunch debug main app init");
    init();
    super.initState();
  }

  @override
  void dispose() {
    BackgroundTaskManager.singleton.dispose();
    streamC.close();
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
                    stream: streamC.stream,
                    builder: (context, snapshot) => Text("${snapshot.data}"),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                    onPressed: () async {
                      await BackgroundTaskManager.singleton.executeTask(task);
                      setState(() {
                        isInit = false;
                      });
                    },
                    child: const Text("Start Task"))
              ],
            ));
          }),
    );
  }
}

Future<void> testHandle(Object args) async {
  debugPrint("testHandle args : $args");
  var i = 12;
  try {
    await Future.doWhile(() async {
      debugPrint("Executing testHandle $i");

      BackgroundTaskManager.postEvent(args: {
        "stringKey": StringDataField(value: "StringValue"),
        "intKey": IntegerDataField(value: i),
        "doubleKey": DoubleDataField(value: i - .5)
      });
      await Future.delayed(const Duration(seconds: 1));
      i--;
      return i > 0;
    });
    BackgroundTaskManager.postEvent(args: {
      "stringKey": StringDataField(value: "StringValue"),
      "intKey": IntegerDataField(value: i),
      "doubleKey": DoubleDataField(value: i - .5)
    });
    debugPrint("Executing testHandle SUCCESS $i");
  } on Exception catch (e) {
    debugPrint("Executing testHandle FAILURE $i");
    throw e.toString();
  }
}
