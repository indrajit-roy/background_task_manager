import 'package:background_task_manager/interfaces/background_task_i.dart';

/// Representation of a data field that can be passed to the background handle
///
/// Implementations include :
/// ```
/// IntegerDataField, DoubleDataField, BooleanDataField, StringDataField, StringListDataField, IntegerListDataField, DoubleListDataField, BooleanListDataField
/// ```
/// Use one of these to pass data to the background handle
abstract class BackgroundDataField<T extends Object> {
  String get platformKey;
  T get value;

  Map<String, dynamic> toMap() => {"platformKey": platformKey, "value": value};
  BackgroundDataField();

  static BackgroundDataField fromMap(Map<dynamic, dynamic> map) {
    final platformKey = map["platformKey"];
    final value = map["value"];
    switch (platformKey) {
      case "int":
        return IntegerDataField(value: value);
      case "double":
        return DoubleDataField(value: value);
      case "bool":
        return BooleanDataField(value: value);
      case "String":
        return StringDataField(value: value);
      case "List<String>":
        return StringListDataField(value: value);
      case "List<int>":
        return IntegerListDataField(value: value);
      case "List<double>":
        return DoubleListDataField(value: value);
      case "List<bool>":
        return BooleanListDataField(value: value);
      default:
        throw StateError("Could not parse $map. The map isn't a BackgroundDataField.");
    }
  }
}

class IntegerDataField extends BackgroundDataField<int> {
  @override
  final int value;

  IntegerDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "int";
}

class DoubleDataField extends BackgroundDataField<double> {
  @override
  final double value;

  DoubleDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "double";
}

class BooleanDataField extends BackgroundDataField<bool> {
  @override
  final bool value;

  BooleanDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "bool";
}

class StringDataField extends BackgroundDataField<String> {
  @override
  final String value;

  StringDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "String";
}

class StringListDataField extends BackgroundDataField<List<String>> {
  @override
  final List<String> value;

  StringListDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "List<String>";
}

class IntegerListDataField extends BackgroundDataField<List<int>> {
  @override
  final List<int> value;

  IntegerListDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "List<int>";
}

class DoubleListDataField extends BackgroundDataField<List<double>> {
  @override
  final List<double> value;

  DoubleListDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "List<double>";
}

class BooleanListDataField extends BackgroundDataField<List<bool>> {
  @override
  final List<bool> value;

  BooleanListDataField({
    required this.value,
  }) : super();

  @override
  String get platformKey => "List<bool>";
}

//! Cant add because Worker does not support sending Maps in workData
// class MapDataField extends BackgroundDataField<Map<String, BackgroundDataField<Object>>> {
//   @override
//   final Map<String, BackgroundDataField<Object>> value;
//   MapDataField({
//     required this.value,
//   }) : super();
//   @override
//   String get platformKey => "Map<String, BackgroundDataField<Object>>";
// }
