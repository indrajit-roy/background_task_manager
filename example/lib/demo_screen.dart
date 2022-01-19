import 'package:background_task_manager/background_task_manager.dart';
import 'package:background_task_manager/interfaces/background_task_i.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

Future<void> handle(obj) async {
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
  final list = List.generate(obj["length"], (index) => factorial(index));
  sw.stop();
  BackgroundTaskManager.postEvent(
      args: {"hello": StringDataField(value: "factorial list of ${list.length} generated in ${sw.elapsedMilliseconds} ms")});
  await Future.delayed(const Duration(seconds: 2));
  print("This is background Flutter");
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({Key? key}) : super(key: key);

  @override
  _DemoScreenState createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  String? tag;

  @override
  void initState() {
    BackgroundTaskManager.singleton.init();
    super.initState();
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
                    onPressed: () {
                      final task = BtmTask(taskId: "taskId1", tag: "tag", args: {"length": IntegerDataField(value: 90000000)}, handle: handle);
                      BackgroundTaskManager.singleton.executeTask(task);
                    },
                    child: const Text("Start task with tag")),
              ],
            ),
            StreamBuilder(
              initialData: null,
              stream: BackgroundTaskManager.singleton.getEventStreamFor("taskId1"),
              builder: (context, snapshot) {
                if (snapshot.data == null) return const Text("No Status Update");
                return Text(snapshot.data.toString());
              },
            )
          ],
        ),
      ),
    );
  }
}
