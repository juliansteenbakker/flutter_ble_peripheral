class DuplicatedOperation implements Error {
  @override
  final StackTrace stackTrace;
  final String msg;

  const DuplicatedOperation(String? msg, this.stackTrace) :
    msg = msg ?? "Operation already ongoing";

  @override
  String toString() => 'DuplicatedOperation: $msg';
}
