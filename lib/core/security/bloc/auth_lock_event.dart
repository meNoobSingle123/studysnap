import 'package:equatable/equatable.dart';

sealed class AuthLockEvent extends Equatable {
  const AuthLockEvent();

  @override
  List<Object?> get props => [];
}

/// Kiểm tra trạng thái khóa ban đầu và khả năng sinh trắc học của thiết bị.
class CheckAuthStatus extends AuthLockEvent {
  const CheckAuthStatus();
}

/// Yêu cầu xác thực qua local_auth (vân tay / FaceID / PIN).
class AuthenticateWithBiometrics extends AuthLockEvent {
  const AuthenticateWithBiometrics();
}

/// Khóa ứng dụng thủ công hoặc khi timeout.
class LockApp extends AuthLockEvent {
  const LockApp();
}

/// Mở khóa ứng dụng trực tiếp (sau khi xác thực thành công hoặc bypass).
class UnlockApp extends AuthLockEvent {
  const UnlockApp();
}

/// Ứng dụng chuyển sang chế độ nền (Background / Paused).
class AppEnteredBackground extends AuthLockEvent {
  final DateTime? timestamp;

  const AppEnteredBackground({this.timestamp});

  @override
  List<Object?> get props => [timestamp];
}

/// Ứng dụng quay trở lại giao diện hoạt động (Resumed).
class AppResumed extends AuthLockEvent {
  final DateTime? timestamp;

  const AppResumed({this.timestamp});

  @override
  List<Object?> get props => [timestamp];
}
