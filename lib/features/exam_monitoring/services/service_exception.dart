class ServiceException implements Exception {
  const ServiceException(
    this.message, {
    this.code,
    this.cause,
    this.stackTrace,
  });

  final String message;
  final String? code;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() {
    if (code == null || code!.isEmpty) {
      return 'ServiceException: $message';
    }
    return 'ServiceException($code): $message';
  }
}
