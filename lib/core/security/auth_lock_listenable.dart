import 'package:flutter/foundation.dart';

/// Notifier cầu nối giữa AuthLockBloc và GoRouter refreshListenable
/// giúp GoRouter kích hoạt lại hàm redirect ngay khi trạng thái khóa thay đổi
/// mà không gây rò rỉ StreamSubscription hay lỗi vòng lặp điều hướng.
class AuthLockListenable extends ChangeNotifier {
  static final AuthLockListenable instance = AuthLockListenable._();
  AuthLockListenable._();

  bool _isLocked = true;
  bool _isLockEnabled = false;

  bool get isLocked => _isLocked;
  bool get isLockEnabled => _isLockEnabled;

  void setLockEnabled(bool enabled) {
    if (_isLockEnabled != enabled) {
      _isLockEnabled = enabled;
      notifyListeners();
    }
  }

  void updateLockState(bool locked) {
    if (_isLocked != locked) {
      _isLocked = locked;
      notifyListeners();
    }
  }
}
