import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/usecases/compress_lecture_image_usecase.dart';
import '../../domain/usecases/parse_qr_code_usecase.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

typedef PermissionStatusGetter = Future<PermissionStatus> Function();

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final ParseQrCodeUseCase parseQrCodeUseCase;
  final CompressLectureImageUseCase compressLectureImageUseCase;
  final ImagePicker imagePicker;
  final PermissionStatusGetter _checkPermission;
  final PermissionStatusGetter _requestPermission;

  ScannerBloc({
    required this.parseQrCodeUseCase,
    required this.compressLectureImageUseCase,
    ImagePicker? imagePicker,
    PermissionStatusGetter? checkPermission,
    PermissionStatusGetter? requestPermission,
  })  : imagePicker = imagePicker ?? ImagePicker(),
        _checkPermission = checkPermission ?? (() => Permission.camera.status),
        _requestPermission =
            requestPermission ?? (() => Permission.camera.request()),
        super(const ScannerState()) {
    on<CheckCameraPermission>(_onCheckCameraPermission);
    on<RequestCameraPermission>(_onRequestCameraPermission);
    on<QrCodeScanned>(_onQrCodeScanned);
    on<ClearQrResult>(_onClearQrResult);
    on<CapturePhotoRequested>(_onCapturePhotoRequested);
    on<PickGalleryPhotoRequested>(_onPickGalleryPhotoRequested);
    on<RemoveCapturedPhoto>(_onRemoveCapturedPhoto);
  }

  Future<void> _onCheckCameraPermission(
    CheckCameraPermission event,
    Emitter<ScannerState> emit,
  ) async {
    try {
      final status = await _checkPermission();
      emit(state.copyWith(cameraPermission: status));
    } catch (_) {
      emit(state.copyWith(cameraPermission: PermissionStatus.denied));
    }
  }

  Future<void> _onRequestCameraPermission(
    RequestCameraPermission event,
    Emitter<ScannerState> emit,
  ) async {
    try {
      final status = await _requestPermission();
      emit(state.copyWith(cameraPermission: status));
    } catch (_) {
      emit(state.copyWith(cameraPermission: PermissionStatus.denied));
    }
  }

  void _onQrCodeScanned(
    QrCodeScanned event,
    Emitter<ScannerState> emit,
  ) {
    final result = parseQrCodeUseCase(event.rawContent);
    emit(state.copyWith(
      qrResult: () => result,
      errorMessage: () => result is QrParseFailure ? result.errorMessage : null,
    ));
  }

  void _onClearQrResult(
    ClearQrResult event,
    Emitter<ScannerState> emit,
  ) {
    emit(state.copyWith(
      qrResult: () => null,
      errorMessage: () => null,
      notificationMessage: () => null,
    ));
  }

  Future<void> _onCapturePhotoRequested(
    CapturePhotoRequested event,
    Emitter<ScannerState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true));
    try {
      final picked = await imagePicker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        final rawFile = File(picked.path);
        final compressed = await compressLectureImageUseCase(rawFile);
        final updatedList = List<File>.from(state.capturedImages)..add(compressed);
        emit(state.copyWith(
          isProcessing: false,
          capturedImages: updatedList,
          notificationMessage: () => 'Đã chụp và nén ảnh thành công',
        ));
      } else {
        emit(state.copyWith(isProcessing: false));
      }
    } catch (e) {
      emit(state.copyWith(
        isProcessing: false,
        errorMessage: () => 'Không thể chụp ảnh: ${e.toString()}',
      ));
    }
  }

  Future<void> _onPickGalleryPhotoRequested(
    PickGalleryPhotoRequested event,
    Emitter<ScannerState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true));
    try {
      final picked = await imagePicker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final rawFile = File(picked.path);
        final compressed = await compressLectureImageUseCase(rawFile);
        final updatedList = List<File>.from(state.capturedImages)..add(compressed);
        emit(state.copyWith(
          isProcessing: false,
          capturedImages: updatedList,
          notificationMessage: () => 'Đã thêm và nén ảnh thành công',
        ));
      } else {
        emit(state.copyWith(isProcessing: false));
      }
    } catch (e) {
      emit(state.copyWith(
        isProcessing: false,
        errorMessage: () => 'Không thể chọn ảnh: ${e.toString()}',
      ));
    }
  }

  void _onRemoveCapturedPhoto(
    RemoveCapturedPhoto event,
    Emitter<ScannerState> emit,
  ) {
    if (event.index >= 0 && event.index < state.capturedImages.length) {
      final updatedList = List<File>.from(state.capturedImages)..removeAt(event.index);
      emit(state.copyWith(capturedImages: updatedList));
    }
  }
}
