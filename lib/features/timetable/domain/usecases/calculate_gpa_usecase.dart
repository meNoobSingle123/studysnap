enum GpaProjectionStatus {
  achievable,
  alreadyAchieved,
  impossible,
  invalidInput,
}

class GpaProjectionResult {
  final double requiredGpa;
  final GpaProjectionStatus status;
  final String message;

  const GpaProjectionResult({
    required this.requiredGpa,
    required this.status,
    required this.message,
  });
}

/// UseCase tính toán dự phóng GPA (Chủ đề 2 - SRS mục 7.2).
///
/// Công thức:
/// G_need = [G_target * (T_done + T_left) - G_now * T_done] / T_left
class CalculateGpaUseCase {
  const CalculateGpaUseCase();

  GpaProjectionResult execute({
    required double currentGpa,
    required int completedCredits,
    required int remainingCredits,
    required double targetGpa,
  }) {
    // 1. Kiểm tra đầu vào hợp lệ
    if (currentGpa < 0 || currentGpa > 4.0 || targetGpa < 0 || targetGpa > 4.0) {
      return const GpaProjectionResult(
        requiredGpa: 0,
        status: GpaProjectionStatus.invalidInput,
        message: 'Điểm GPA phải nằm trong khoảng từ 0.0 đến 4.0',
      );
    }

    if (completedCredits < 0 || remainingCredits < 0) {
      return const GpaProjectionResult(
        requiredGpa: 0,
        status: GpaProjectionStatus.invalidInput,
        message: 'Số tín chỉ không được âm',
      );
    }

    // Trường hợp không còn tín chỉ nào
    if (remainingCredits == 0) {
      if (currentGpa >= targetGpa) {
        return const GpaProjectionResult(
          requiredGpa: 0,
          status: GpaProjectionStatus.alreadyAchieved,
          message: 'Đã đạt mục tiêu',
        );
      } else {
        return const GpaProjectionResult(
          requiredGpa: 0,
          status: GpaProjectionStatus.impossible,
          message: 'Không khả thi',
        );
      }
    }

    // 2. Tính toán theo công thức
    final totalCredits = completedCredits + remainingCredits;
    final totalPointsNeeded = targetGpa * totalCredits;
    final currentPoints = currentGpa * completedCredits;
    final neededPoints = totalPointsNeeded - currentPoints;
    final requiredGpa = neededPoints / remainingCredits;

    // 3. Phân loại kết quả theo đặc tả mục 7.2
    if (requiredGpa > 4.0) {
      return GpaProjectionResult(
        requiredGpa: requiredGpa,
        status: GpaProjectionStatus.impossible,
        message: 'Không khả thi',
      );
    } else if (requiredGpa <= 0.0) {
      return const GpaProjectionResult(
        requiredGpa: 0.0,
        status: GpaProjectionStatus.alreadyAchieved,
        message: 'Đã đạt mục tiêu',
      );
    } else {
      return GpaProjectionResult(
        requiredGpa: double.parse(requiredGpa.toStringAsFixed(2)),
        status: GpaProjectionStatus.achievable,
        message: 'Cần đạt: ${requiredGpa.toStringAsFixed(2)} / 4.0',
      );
    }
  }
}
