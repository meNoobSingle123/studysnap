import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/timetable/domain/usecases/calculate_gpa_usecase.dart';

void main() {
  late CalculateGpaUseCase useCase;

  setUp(() {
    useCase = const CalculateGpaUseCase();
  });

  group('CalculateGpaUseCase (Chủ đề 2 - 5 Unit Tests theo SRS mục 7.2)', () {
    test('1. Điểm cần đạt bình thường khả thi (G_need trong khoảng 0.0 đến 4.0)', () {
      // GPA hiện tại 3.0, 60 tín chỉ xong, còn 30 tín chỉ, mục tiêu 3.2
      // G_need = [3.2 * 90 - 3.0 * 60] / 30 = [288 - 180] / 30 = 3.60
      final result = useCase.execute(
        currentGpa: 3.0,
        completedCredits: 60,
        remainingCredits: 30,
        targetGpa: 3.2,
      );

      expect(result.status, GpaProjectionStatus.achievable);
      expect(result.requiredGpa, 3.60);
      expect(result.message, contains('3.60'));
    });

    test('2. Điểm đã đạt mục tiêu (G_need <= 0)', () {
      // GPA hiện tại 3.8, 90 tín chỉ xong, còn 10 tín chỉ, mục tiêu 3.0
      // G_need = [3.0 * 100 - 3.8 * 90] / 10 = -4.2 <= 0
      final result = useCase.execute(
        currentGpa: 3.8,
        completedCredits: 90,
        remainingCredits: 10,
        targetGpa: 3.0,
      );

      expect(result.status, GpaProjectionStatus.alreadyAchieved);
      expect(result.message, 'Đã đạt mục tiêu');
    });

    test('3. Điểm không khả thi (G_need > 4.0)', () {
      // GPA hiện tại 2.0, 90 tín chỉ xong, còn 10 tín chỉ, mục tiêu 3.5
      // G_need = [3.5 * 100 - 2.0 * 90] / 10 = 17.0 > 4.0
      final result = useCase.execute(
        currentGpa: 2.0,
        completedCredits: 90,
        remainingCredits: 10,
        targetGpa: 3.5,
      );

      expect(result.status, GpaProjectionStatus.impossible);
      expect(result.message, 'Không khả thi');
    });

    test('4. Không còn tín chỉ nào còn lại (T_left = 0)', () {
      // Trường hợp 4a: Đã đạt (current >= target)
      final resultPass = useCase.execute(
        currentGpa: 3.5,
        completedCredits: 120,
        remainingCredits: 0,
        targetGpa: 3.2,
      );
      expect(resultPass.status, GpaProjectionStatus.alreadyAchieved);

      // Trường hợp 4b: Không thể đạt (current < target)
      final resultFail = useCase.execute(
        currentGpa: 2.8,
        completedCredits: 120,
        remainingCredits: 0,
        targetGpa: 3.2,
      );
      expect(resultFail.status, GpaProjectionStatus.impossible);
    });

    test('5. Dữ liệu đầu vào không hợp lệ (ngoài thang 0.0 - 4.0 hoặc tín chỉ âm)', () {
      final resultInvalidGpa = useCase.execute(
        currentGpa: 4.5,
        completedCredits: 60,
        remainingCredits: 30,
        targetGpa: 3.5,
      );
      expect(resultInvalidGpa.status, GpaProjectionStatus.invalidInput);

      final resultNegativeCredits = useCase.execute(
        currentGpa: 3.0,
        completedCredits: -10,
        remainingCredits: 30,
        targetGpa: 3.5,
      );
      expect(resultNegativeCredits.status, GpaProjectionStatus.invalidInput);
    });
  });
}
