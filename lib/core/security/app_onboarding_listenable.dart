import 'package:flutter/foundation.dart';

/// Listenable cầu nối giữa KeyStorageService và GoRouter refreshListenable
/// giúp GoRouter tự động chuyển hướng đến màn hình chào mừng (Onboarding)
/// trong lần đầu tiên mở ứng dụng mà không gây trễ hoặc lỗi điều hướng.
class AppOnboardingListenable extends ChangeNotifier {
  static final AppOnboardingListenable instance = AppOnboardingListenable._();
  AppOnboardingListenable._();

  bool _isCompleted = false;

  bool get isCompleted => _isCompleted;

  void setCompleted(bool completed) {
    if (_isCompleted != completed) {
      _isCompleted = completed;
      notifyListeners();
    }
  }
}

