class UnsupportedOperation implements Error {
  @override
  final StackTrace stackTrace;
  final String msg;

  const UnsupportedOperation(this.msg, this.stackTrace);

  @override
  String toString() => 'UnsupportedOperation: $msg';
}
