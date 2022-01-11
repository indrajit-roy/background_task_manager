import 'dart:convert';

abstract class BackgroundServiceInterface {
  Future<BackgroundOperation> enqueueTask<T>({required BackgroundTaskRequest<T> request});
}

class BackgroundTaskRequest<T> {
  final String id;
  final BackgroundTask task;
  final T Function(dynamic args) converter;
  final dynamic args;

  const BackgroundTaskRequest({required this.id, required this.task, required this.converter, this.args});
}

class BackgroundOperation<T> {
  final String id;
  final Stream<T> progress;

  const BackgroundOperation({required this.id, required this.progress});
}


typedef BackgroundTask = Future<void> Function(Object message);
