class InvalidServiceUUID implements Exception {
  final String uuid;
  final String msg;

  const InvalidServiceUUID(this.uuid, this.msg);

  @override
  String toString() => 'InvalidServiceUUID: $msg';
}
