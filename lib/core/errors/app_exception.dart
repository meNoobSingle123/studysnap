/// Base exception for application-level errors.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

/// Thrown when a network-related issue occurs.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.details});
}

/// Thrown when local storage or database (Hive) operations fail.
class StorageException extends AppException {
  const StorageException(super.message, {super.code, super.details});
}

/// Thrown when input or business validation fails.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.details});
}

/// Thrown when required system permissions are not granted.
class PermissionException extends AppException {
  const PermissionException(super.message, {super.code, super.details});
}

/// Thrown when server responds with an error or invalid payload.
class ServerException extends AppException {
  const ServerException(super.message, {super.code, super.details});
}
