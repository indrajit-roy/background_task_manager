import 'dart:async';

import 'package:background_task_manager/background_task_manager.dart';
import 'package:background_task_manager/interfaces/background_task_i.dart';
import 'package:background_task_manager_example/demo/models/event_object.dart';
import 'package:flutter/widgets.dart';

import 'background_service_i.dart';

class BackgroundService implements ColcoBackgroundService {
  final service = BackgroundTaskManager();

  @override
  Future<ColcoBackgroundTask> enqueueBackgroundTask<T>({required ColcoBackgroundTaskRequest<T> taskRequest}) {
    // service.executeTask(task)
    throw UnimplementedError();
  }

  @override
  Future<List<ColcoBackgroundTask>> getActiveTasks() {
    // TODO: implement getActiveTasks
    throw UnimplementedError();
  }

  @override
  Future<bool> init() async {
    try {
      await service.init(
        modelMap: BtmModelMap.mapper().addModel<EventObject>(type: "EventObject", converter: (map) => EventObject.fromMap(map)).buildMap(),
      );
      return true;
    } on Exception catch (e) {
      debugPrint("BackgroundService init exception $e");
      return false;
    } on Error catch (e) {
      debugPrint("BackgroundService init error $e");
      return false;
    }
  }

  @override
  void dispose() {
    service.dispose();
  }
}

class Task extends ColcoBackgroundTask {
  final BackgroundTaskManager taskManager;
  @override
  final String id;
  @override
  final String? tag;
  final String? type;
  ColcoBackgroundTaskStatus _status;
  final Completer<ColcoBackgroundTaskStatus> _completer = Completer<ColcoBackgroundTaskStatus>();

  Task(this.taskManager, {required this.id, required ColcoBackgroundTaskStatus status, required this.tag, required this.type}) : _status = status {
    if (isFinished) _completer.complete(_status);
  }

  @override
  bool get isFinished => _status.isFinished || _status.didFail;

  @override
  ColcoBackgroundTaskStatus get currentStatus => _status;

  @override
  Stream<ColcoBackgroundTaskStatus> get statusStream {
    return taskManager.getEventStreamFor(id).where((event) => event is EventObject).map((event) {
      final eventObject = event as EventObject;
      if (eventObject.running) {
        return ColcoBackgroundTaskStatus.running(progress: eventObject);
      } else if (eventObject.success) {
        return ColcoBackgroundTaskStatus.finished(progress: 1, result: eventObject);
      } else {
        return ColcoBackgroundTaskStatus.failed(error: "Some Error", progress: 1, result: eventObject);
      }
    });
  }

  @override
  Future<ColcoBackgroundTaskStatus> task() => _completer.future;
}

class TaskRequest<T> extends ColcoBackgroundTaskRequest<T> {
  @override
  // ignore: overridden_fields
  final Future<void> Function(Object?) callBack;
  TaskRequest({required this.callBack, final String? tag, T? args}) : super(callBack: callBack, tag: tag, args: args);
}
extension Ext<T> on ColcoBackgroundTaskRequest<T> {
  BtmTask get btmTask => BtmTask(type: T.toString(), handle: callBack as Future<void> Function(Object?));
}