
import 'dart:typed_data';

class MessagePacket {
  final String characteristicUUID;
  final Uint8List value;
  //final Device origin;

  MessagePacket(this.characteristicUUID, this.value);

  MessagePacket.fromMap(Map<String,dynamic> map) :
        characteristicUUID = map["characteristic"] as String,
        value = map["value"] as Uint8List;

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true;

    if (other.runtimeType != runtimeType)
      return false;

    if (!(other is MessagePacket) || other.characteristicUUID != characteristicUUID || other.value.length != value.length)
      return false;

    for (int i = 0; i < value.length; i++)
        if (other.value[i] != value[i])
          return false;

    return true;
  }
}
