import 'package:equatable/equatable.dart';

sealed class ScannerEvent extends Equatable {
  const ScannerEvent();

  @override
  List<Object?> get props => [];
}

class CheckCameraPermission extends ScannerEvent {
  const CheckCameraPermission();
}

class RequestCameraPermission extends ScannerEvent {
  const RequestCameraPermission();
}

class QrCodeScanned extends ScannerEvent {
  final String rawContent;

  const QrCodeScanned(this.rawContent);

  @override
  List<Object?> get props => [rawContent];
}

class ClearQrResult extends ScannerEvent {
  const ClearQrResult();
}

class CapturePhotoRequested extends ScannerEvent {
  const CapturePhotoRequested();
}

class PickGalleryPhotoRequested extends ScannerEvent {
  const PickGalleryPhotoRequested();
}

class RemoveCapturedPhoto extends ScannerEvent {
  final int index;

  const RemoveCapturedPhoto(this.index);

  @override
  List<Object?> get props => [index];
}
