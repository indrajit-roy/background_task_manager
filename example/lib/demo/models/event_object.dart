import 'dart:convert';

import 'package:background_task_manager/interfaces/background_task_i.dart';

class EventObject extends BackgroundEvent {
  final String eventId;
  final String? newEventId;
  final double progress;
  final List<String>? idList;
  final bool success;
  final bool running;
  final List<SubEventObject>? subEvents;
  const EventObject({
    required this.eventId,
    this.newEventId,
    required this.progress,
    this.idList,
    required this.success,
    required this.running,
    required this.subEvents,
  });

  factory EventObject.fromJson(String source) => EventObject.fromMap(json.decode(source));
  factory EventObject.fromMap(Map<Object?, Object?> map) {
    final eventId = map["eventId"];
    final progress = map["progress"];
    final success = map["success"];
    final running = map["running"];
    final newEventId = map["newEventId"];
    final subEvents = (map["subEvents"] as List?)?.map((e) => SubEventObject.fromMap(e)).toList();
    final idList = map["idList"];
    if (eventId is! String) throw AssertionError("eventId : $eventId, must be String and not null");
    if (progress is! double) throw AssertionError("progress : $progress, must be double and not null");
    if (success is! bool) throw AssertionError("success : $success, must be bool and not null");
    if (running is! bool) throw AssertionError("running : $running, must be bool and not null");
    if (newEventId is! String?) throw AssertionError("newEventId : $newEventId, must be String?");
    if (idList is! List<String>?) throw AssertionError("idList : $idList, must be List<String>?");

    return EventObject(
        eventId: eventId, progress: progress, success: success, running: running, subEvents: subEvents, newEventId: newEventId, idList: idList);
  }
  
  @override
  Map<Object?, Object?> toMap() => {
        "eventId": eventId,
        "newEventId": newEventId,
        "progress": progress,
        "idList": idList,
        "success": success,
        "running": running,
        "subEvents": subEvents?.map((e) => e.toMap()).toList()
      };
}

class SubEventObject extends BackgroundEvent {
  final String id;
  final String? newId;

  const SubEventObject(this.id, {this.newId});
  @override
  Map<Object?, Object?> toMap() => {
        "id": id,
        "newId": newId,
      };

  factory SubEventObject.fromJson(String source) => SubEventObject.fromMap(json.decode(source));
  factory SubEventObject.fromMap(Map<Object?, Object?> map) {
    final id = map["id"];
    final newId = map["newId"];
    if (id is! String) throw AssertionError("id : $id, must be String and not null");
    if (newId is! String?) throw AssertionError("newId : $newId, must be String?");
    return SubEventObject(id, newId: newId);
  }
}
