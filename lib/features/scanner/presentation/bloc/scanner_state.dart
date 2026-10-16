import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/usecases/parse_qr_code_usecase.dart';

class ScannerState extends Equatable {
  final PermissionStatus cameraPermission;
  final bool isProcessing;
  final List<File> capturedImages;
  final QrParseResult? qrResult;
  final String? errorMessage;
  final String? notificationMessage;

  const ScannerState({
    this.cameraPermission = PermissionStatus.denied,
    this.isProcessing = false,
    this.capturedImages = const [],
    this.qrResult,
    this.errorMessage,
    this.notificationMessage,
  });

  bool get hasCameraPermission => cameraPermission.isGranted;

  ScannerState copyWith({
    PermissionStatus? cameraPermission,
    bool? isProcessing,
    List<File>? capturedImages,
    QrParseResult? Function()? qrResult,
    String? Function()? errorMessage,
    String? Function()? notificationMessage,
  }) {
    return ScannerState(
      cameraPermission: cameraPermission ?? this.cameraPermission,
      isProcessing: isProcessing ?? this.isProcessing,
      capturedImages: capturedImages ?? this.capturedImages,
      qrResult: qrResult != null ? qrResult() : this.qrResult,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      notificationMessage: notificationMessage != null
          ? notificationMessage()
          : this.notificationMessage,
    );
  }

  @override
  List<Object?> get props => [
        cameraPermission,
        isProcessing,
        capturedImages,
        qrResult,
        errorMessage,
        notificationMessage,
      ];
}
