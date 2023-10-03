class InvalidCharacteristicUUID implements Exception {
  final String uuid;
  final String msg;

  const InvalidCharacteristicUUID(this.uuid, this.msg);

  @override
  String toString() => 'InvalidCharacteristicUUID: $msg';
}
