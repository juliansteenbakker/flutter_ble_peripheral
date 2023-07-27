import 'dart:typed_data';

class CharacteristicDescription {
  final String uuid;
  final Uint8List value;
  final bool read;
  final bool write;
  final bool notify;
  final bool indicate;

  CharacteristicDescription({
    required String uuid,
    Uint8List? value,
    this.read = false,
    this.write = false,
    this.notify = false,
    this.indicate = false,
  }) :
    uuid = uuid.toLowerCase(),
    value = value ?? Uint8List(0)
  ;

  Map<String, dynamic> toMap() {
    return {
      "uuid": uuid,
      "value": value,
      "read": read,
      "write": write,
      "notify": notify,
      "indicate": indicate
    };
  }
}
