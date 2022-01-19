import 'dart:async';

import 'package:background_task_manager/background_task_manager.dart';
import 'package:flutter/material.dart';

import 'demo_screen.dart';

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
  @override
  Widget build(BuildContext context) {
    return const DemoScreen();
  }
}

Future<void> testHandle(Object? args) async {
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
      "status": StringDataField(value: "success"),
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
