import 'package:equatable/equatable.dart';

sealed class AuthLockState extends Equatable {
  const AuthLockState();

  @override
  List<Object?> get props => [];
}

/// Trạng thái khởi tạo.
class AuthLockInitial extends AuthLockState {
  const AuthLockInitial();
}

/// Ứng dụng đang trong trạng thái bị khóa (Hiển thị màn hình S01).
class AuthLocked extends AuthLockState {
  final String? errorMessage;
  final bool isAuthenticating;

  const AuthLocked({
    this.errorMessage,
    this.isAuthenticating = false,
  });

  @override
  List<Object?> get props => [errorMessage, isAuthenticating];
}

/// Ứng dụng đã mở khóa thành công (Cho phép truy cập các tab học tập).
class AuthUnlocked extends AuthLockState {
  const AuthUnlocked();
}

/// Thiết bị không hỗ trợ sinh trắc học hoặc chưa thiết lập mã PIN bảo vệ.
class BiometricsNotAvailable extends AuthLockState {
  final String message;

  const BiometricsNotAvailable({
    this.message = 'Thiết bị chưa thiết lập sinh trắc học hoặc mã PIN',
  });

  @override
  List<Object?> get props => [message];
}
