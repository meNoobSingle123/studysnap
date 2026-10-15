import 'package:equatable/equatable.dart';

/// Base Failure class representing domain-level failures.
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Failure mapped from network errors.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

/// Failure mapped from local storage / Hive errors.
class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.code});
}

/// Failure mapped from validation errors.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

/// Failure mapped from permission denial.
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.code});
}

/// Failure mapped from remote server errors.
class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

/// Failure mapped from unexpected errors.
class UnknownFailure extends Failure {
  const UnknownFailure([
    super.message = 'An unexpected error occurred.',
    String? code,
  ]) : super(code: code);
}
