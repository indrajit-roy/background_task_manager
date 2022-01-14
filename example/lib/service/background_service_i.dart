
import 'dart:async';

abstract class ColcoBackgroundService {
  FutureOr<bool> init();
  void dispose();
  Future<List<ColcoBackgroundTask>> getActiveTasks();
  Future<ColcoBackgroundTask> enqueueBackgroundTask<T>({required ColcoBackgroundTaskRequest<T> taskRequest});
}

abstract class ColcoBackgroundTaskRequest<T> {
  final String? tag;
  final Function callBack;
  final T? args;
  const ColcoBackgroundTaskRequest({required this.callBack, this.tag, this.args});
}

abstract class ColcoBackgroundTask {
  String get id;
  String? get tag;
  ColcoBackgroundTaskStatus get currentStatus;
  bool get isFinished;
  Stream<ColcoBackgroundTaskStatus> get statusStream;
  Future<ColcoBackgroundTaskStatus> task();
}

class ColcoBackgroundTaskStatus {
  final bool isQueued;
  final bool isRunning;
  final bool isFinished;
  final bool didFail;
  final dynamic result;
  final dynamic progress;
  final dynamic error;
  const ColcoBackgroundTaskStatus.queued()
      : isQueued = true,
        isRunning = false,
        isFinished = false,
        didFail = false,
        result = null,
        progress = null,
        error = null;
  const ColcoBackgroundTaskStatus.running({this.progress})
      : isQueued = false,
        isRunning = true,
        isFinished = false,
        didFail = false,
        result = null,
        error = null;
  const ColcoBackgroundTaskStatus.finished({this.result, this.progress})
      : isQueued = false,
        isRunning = false,
        isFinished = true,
        didFail = false,
        error = null;
  const ColcoBackgroundTaskStatus.failed({this.error, this.result, this.progress})
      : isQueued = false,
        isRunning = false,
        isFinished = false,
        didFail = true;
}
