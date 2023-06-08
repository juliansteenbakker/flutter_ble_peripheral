
import 'dart:typed_data';

class MessagePacket {
  final String characteristicUUID;
  final Uint8List value;
  //final Device origin;

  MessagePacket(this.characteristicUUID, this.value);

  MessagePacket.fromMap(Map<String,dynamic> map) :
        characteristicUUID = map["characteristic"] as String,
        value = map["value"] as Uint8List;
}
