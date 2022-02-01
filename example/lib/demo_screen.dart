import 'dart:async';

import 'package:background_task_manager/background_task_manager.dart';
import 'package:background_task_manager/interfaces/background_task_i.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

Future<PlatformArguments> handle(obj) async {
  num factorial(num input) {
    var num = 5;
    var factorial = 1;

    for (var i = num; i >= 1; i--) {
      factorial *= i;
    }
    return factorial;
  }

  print("Background args : $obj");
  Stopwatch sw = Stopwatch();
  BackgroundTaskManager.postEvent(args: {"hello": StringDataField(value: "datafield")});
  sw.start();
  final list = List.generate(obj["length"], (index) => index);
  await Future.forEach<int>(list, (element) async {
    factorial(element);
    await Future.delayed(const Duration(seconds: 1));
    BackgroundTaskManager.postEvent(args: {"hello": StringDataField(value: "factorial event $element")});
  });
  BackgroundTaskManager.postEvent(
      args: {"hello": StringDataField(value: "factorial list of ${list.length} generated in ${sw.elapsedMilliseconds} ms")});
  sw.stop();
  print("This is background Flutter");
  return {"result": StringDataField(value: "I am result after ${sw.elapsedMilliseconds} ms and generating factorial of ${list.length} no.s")};
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({Key? key}) : super(key: key);

  @override
  _DemoScreenState createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  String? tag;
  final progress = BehaviorSubject.seeded("Nothing Queued");
  final tags = ["tag1", "tag2", "tag3"];

  @override
  void initState() {
    BackgroundTaskManager.singleton.init();
    super.initState();
  }

  @override
  void dispose() {
    BackgroundTaskManager.singleton.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: "Enter Tag"),
                    onChanged: (value) {},
                  ),
                ),
                ElevatedButton(
                    onPressed: () async {
                      final task =
                          await BackgroundTaskManager.singleton.executeTask(handle, args: {"length": IntegerDataField(value: 9000)}, tag: "tag1");
                      BackgroundTaskManager.singleton.getEventStreamForTask(task.taskId).listen((event) {
                        progress.value = event.toString();
                      });
                    },
                    child: const Text("Start task with tag")),
              ],
            ),
            ElevatedButton(
              onPressed: () async {
                final tasks = await BackgroundTaskManager.singleton.getTasksWithTag("tag1");
                progress.value = tasks.toString();
              },
              child: const Text("Get Tagged tasks"),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: tags.length,
                itemBuilder: (context, index) {
                  return TasksByTag(tag: tags[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TasksByTag extends StatefulWidget {
  final String tag;
  const TasksByTag({Key? key, required this.tag}) : super(key: key);

  @override
  TasksByTagState createState() => TasksByTagState();
}

class TasksByTagState extends State<TasksByTag> {
  var tasks = <BackgroundTaskInfo>[];

  init() async {
    final tasks = await BackgroundTaskManager.singleton.getTasksWithUniqueWorkName(widget.tag);
    debugPrint("tagged tasks for ${widget.tag} : $tasks");
    if (tasks.isNotEmpty) {
      setState(() {
        this.tasks = tasks;
      });
    }
  }

  @override
  void initState() {
    init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tasks.length,
              itemExtent: 120,
              itemBuilder: (context, index) {
                return TaskView(id: tasks[index].taskId);
              },
            ),
          ),
          ElevatedButton(
              onPressed: () async {
                final str = await compute((ar) async {
                  return List.generate(90000, (index) => "$index").reduce((value, element) => "$value$element");
                }, "");
                final Map<String, BackgroundDataField<Object>>? args = {"length": IntegerDataField(value: 20), "string": StringDataField(value: str)};
                 final task = await BackgroundTaskManager.singleton.executeTask(handle, args: args, tag: widget.tag);
                  tasks.add(task);
                  setState(() {});
                // init();
              },
              child: Text("Queue with ${widget.tag}"))
        ],
      ),
    );
  }
}

class TaskView extends StatefulWidget {
  final String id;
  const TaskView({Key? key, required this.id}) : super(key: key);

  @override
  _TaskViewState createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  StreamSubscription? subscription;
  String str = "No data";

  @override
  void initState() {
    subscription = BackgroundTaskManager.singleton.getEventStreamForTask(widget.id).listen((event) {
      setState(() {
        str = event.toString();
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 8,
      child: Text(
        str,
        softWrap: true,
      ),
    );
  }
}
