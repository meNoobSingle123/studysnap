import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/scanner/domain/usecases/compress_lecture_image_usecase.dart';
import 'package:nhom_7/features/scanner/domain/usecases/parse_qr_code_usecase.dart';
import 'package:nhom_7/features/scanner/presentation/bloc/scanner_bloc.dart';
import 'package:nhom_7/features/scanner/presentation/bloc/scanner_event.dart';
import 'package:nhom_7/features/scanner/presentation/bloc/scanner_state.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  late ParseQrCodeUseCase parseQrCodeUseCase;
  late CompressLectureImageUseCase compressLectureImageUseCase;
  late ScannerBloc bloc;
  PermissionStatus mockStatus = PermissionStatus.denied;

  setUp(() {
    parseQrCodeUseCase = const ParseQrCodeUseCase();
    compressLectureImageUseCase = const CompressLectureImageUseCase();
    mockStatus = PermissionStatus.denied;

    bloc = ScannerBloc(
      parseQrCodeUseCase: parseQrCodeUseCase,
      compressLectureImageUseCase: compressLectureImageUseCase,
      checkPermission: () async => mockStatus,
      requestPermission: () async {
        mockStatus = PermissionStatus.granted;
        return mockStatus;
      },
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('ScannerBloc Unit Tests (Chủ đề 10)', () {
    test('initial state has denied camera permission and empty captured images', () {
      expect(bloc.state.cameraPermission, equals(PermissionStatus.denied));
      expect(bloc.state.hasCameraPermission, isFalse);
      expect(bloc.state.capturedImages, isEmpty);
      expect(bloc.state.qrResult, isNull);
      expect(bloc.state.isProcessing, isFalse);
    });

    test('CheckCameraPermission updates state with current permission status', () async {
      mockStatus = PermissionStatus.granted;
      bloc.add(const CheckCameraPermission());

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<ScannerState>((state) {
            return state.cameraPermission == PermissionStatus.granted &&
                state.hasCameraPermission;
          }),
        ),
      );
    });

    test('RequestCameraPermission requests and grants camera permission', () async {
      bloc.add(const RequestCameraPermission());

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<ScannerState>((state) {
            return state.cameraPermission == PermissionStatus.granted &&
                state.hasCameraPermission;
          }),
        ),
      );
    });

    test('QrCodeScanned with valid doc URL emits QrParseSuccess', () async {
      const validQr =
          'studysnap://doc?url=https%3A%2F%2Ffit.hcmus.edu.vn%2Fsyllabus.pdf';

      bloc.add(const QrCodeScanned(validQr));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<ScannerState>((state) {
            final qr = state.qrResult;
            return qr is QrParseSuccess &&
                qr.link.domain == 'fit.hcmus.edu.vn' &&
                qr.link.documentUrl == 'https://fit.hcmus.edu.vn/syllabus.pdf' &&
                state.errorMessage == null;
          }),
        ),
      );
    });

    test('QrCodeScanned with insecure HTTP URL emits QrParseFailure', () async {
      const insecureQr =
          'studysnap://doc?url=http%3A%2F%2Finsecure.com%2Fdoc.pdf';

      bloc.add(const QrCodeScanned(insecureQr));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<ScannerState>((state) {
            final qr = state.qrResult;
            return qr is QrParseFailure &&
                qr.errorMessage == AppStrings.insecureHttpBlocked &&
                state.errorMessage == AppStrings.insecureHttpBlocked;
          }),
        ),
      );
    });

    test('ClearQrResult resets qrResult and errorMessage', () async {
      bloc.add(const QrCodeScanned('invalid_code'));
      await bloc.stream.firstWhere((s) => s.qrResult != null);

      bloc.add(const ClearQrResult());

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<ScannerState>((state) {
            return state.qrResult == null && state.errorMessage == null;
          }),
        ),
      );
    });

    test('RemoveCapturedPhoto removes image at specific index', () async {
      // Simulate existing image in state
      final dummyFile1 = File('dummy1.jpg');
      final dummyFile2 = File('dummy2.jpg');

      bloc.emit(bloc.state.copyWith(capturedImages: [dummyFile1, dummyFile2]));
      expect(bloc.state.capturedImages.length, equals(2));

      bloc.add(const RemoveCapturedPhoto(0));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<ScannerState>((state) {
            return state.capturedImages.length == 1 &&
                state.capturedImages.first.path == 'dummy2.jpg';
          }),
        ),
      );
    });
  });
}
