import 'dart:typed_data';
import 'package:json_annotation/json_annotation.dart';

class Uint8ListMapIntConverter
    implements JsonConverter<Map<int, Uint8List>?, Map<String, dynamic>?> {
  const Uint8ListMapIntConverter();

  @override
  Map<int, Uint8List>? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    final Map<int, Uint8List> map = {};
    for (final key in json.keys) {
      map[int.parse(key)] = Uint8List.fromList((json[key] as List).cast<int>());
    }

    return map;
  }

  @override
  Map<String, dynamic>? toJson(Map<int, Uint8List>? object) {
    if (object == null) {
      return null;
    }
    final Map<String, dynamic> map = {};
    for (final key in object.keys) {
      map[key.toString()] = object[key]!.toList();
    }
    return map;
  }
}
