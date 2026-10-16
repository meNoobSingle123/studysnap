import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/scanner/domain/usecases/parse_qr_code_usecase.dart';

void main() {
  late ParseQrCodeUseCase useCase;

  setUp(() {
    useCase = const ParseQrCodeUseCase();
  });

  group('ParseQrCodeUseCase (Chủ đề 10 - Quét mã QR theo SRS 7.3)', () {
    test('1. Parsed successfully with encoded HTTPS URL and extracts domain', () {
      const qr =
          'studysnap://doc?url=https%3A%2F%2Ffit.hcmus.edu.vn%2Fsyllabus.pdf';

      final result = useCase(qr);

      expect(result, isA<QrParseSuccess>());
      final success = result as QrParseSuccess;
      expect(success.link.domain, equals('fit.hcmus.edu.vn'));
      expect(
        success.link.documentUrl,
        equals('https://fit.hcmus.edu.vn/syllabus.pdf'),
      );
      expect(success.link.originalQrCode, equals(qr));
    });

    test('2. Parsed successfully with plain HTTPS URL', () {
      const qr =
          'studysnap://doc?url=https://drive.google.com/file/d/123/view';

      final result = useCase(qr);

      expect(result, isA<QrParseSuccess>());
      final success = result as QrParseSuccess;
      expect(success.link.domain, equals('drive.google.com'));
      expect(
        success.link.documentUrl,
        equals('https://drive.google.com/file/d/123/view'),
      );
    });

    test('3. Rejects insecure HTTP protocol according to SRS 7.3', () {
      const qr =
          'studysnap://doc?url=http%3A%2F%2Finsecure-domain.com%2Fdoc.pdf';

      final result = useCase(qr);

      expect(result, isA<QrParseFailure>());
      final failure = result as QrParseFailure;
      expect(failure.errorMessage, equals(AppStrings.insecureHttpBlocked));
    });

    test('4. Rejects invalid scheme (not studysnap)', () {
      const qr = 'otherapp://doc?url=https://fit.hcmus.edu.vn';

      final result = useCase(qr);

      expect(result, isA<QrParseFailure>());
      final failure = result as QrParseFailure;
      expect(failure.errorMessage, equals(AppStrings.invalidQrCode));
    });

    test('5. Rejects invalid action (not doc)', () {
      const qr = 'studysnap://profile?url=https://fit.hcmus.edu.vn';

      final result = useCase(qr);

      expect(result, isA<QrParseFailure>());
      final failure = result as QrParseFailure;
      expect(failure.errorMessage, equals(AppStrings.invalidQrCode));
    });

    test('6. Rejects missing url query parameter', () {
      const qr = 'studysnap://doc';

      final result = useCase(qr);

      expect(result, isA<QrParseFailure>());
      final failure = result as QrParseFailure;
      expect(failure.errorMessage, equals(AppStrings.invalidQrCode));
    });

    test('7. Rejects null or empty string', () {
      expect(useCase(null), isA<QrParseFailure>());
      expect(useCase(''), isA<QrParseFailure>());
      expect(useCase('   '), isA<QrParseFailure>());
    });

    test('8. Rejects raw plain text or invalid URI', () {
      const qr = 'Chào mừng bạn đến với HCMUS';

      final result = useCase(qr);

      expect(result, isA<QrParseFailure>());
      final failure = result as QrParseFailure;
      expect(failure.errorMessage, equals(AppStrings.invalidQrCode));
    });
  });
}
