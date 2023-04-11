class AdvertiseException implements Exception {
  final int? errorCode;
  final String? message;
  final dynamic error;

  AdvertiseException({this.errorCode, this.message, this.error});
}
