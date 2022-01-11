import 'package:background_task_manager_example/background_service/background_service_i.dart';
import 'package:flutter/services.dart';

class BackgroundService implements BackgroundServiceInterface {
  @override
  Future<BackgroundOperation<T>> enqueueTask<T>({required BackgroundTaskRequest<T> request}) async {
    throw UnimplementedError();
    // return BackgroundOperation<T>(id: request.id, progress: _eventStream.where((event) => request.id == event) as Stream<T>);
  }
}
