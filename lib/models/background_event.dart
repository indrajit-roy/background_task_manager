import 'package:background_task_manager/interfaces/background_task_i.dart';

class BackgroundEvent {
  final String taskId;
  final String? tag;
  final BtmTaskStatus status;
  final Map? data;
  const BackgroundEvent({
    required this.taskId,
    required this.status,
    this.tag,
    this.data,
  });

  factory BackgroundEvent.fromMap(Map map) {
    final taskId = map["taskId"];
    if (taskId is! String && map["status"] is! String) {
      throw AssertionError("taskId : $taskId or status ${map["status"]} is null while parsing BackgroundEvent.fromMap");
    }
    final status = BtmTaskStatus.values.asNameMap()[map["status"]];
    if (status == null) throw AssertionError("status : ${map["status"]} is absent in BtmTaskStatus enums");
    return BackgroundEvent(
      taskId: taskId,
      tag: map["tag"],
      status: status,
      data: map["event"],
    );
  }

  @override
  String toString() {
    return 'BackgroundEvent(taskId: $taskId, tag: $tag, status: $status, data: $data)';
  }
}
