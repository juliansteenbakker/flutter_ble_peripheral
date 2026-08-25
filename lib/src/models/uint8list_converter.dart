import 'dart:typed_data';
import 'package:json_annotation/json_annotation.dart';

/// Encodes a [Uint8List] as a plain list of ints, so that it survives the
/// json round trip that `AdvertiseData` uses.
class Uint8ListConverter implements JsonConverter<Uint8List?, List<dynamic>?> {
  /// Creates the converter.
  const Uint8ListConverter();

  @override
  Uint8List? fromJson(List<dynamic>? json) {
    if (json == null) {
      return null;
    }

    return Uint8List.fromList(json.cast<int>());
  }

  @override
  List<int>? toJson(Uint8List? object) {
    if (object == null) {
      return null;
    }

    return object.toList();
  }
}
