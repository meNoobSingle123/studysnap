import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';

class ScannerCameraPage extends StatelessWidget {
  const ScannerCameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ScannerBloc>()..add(const CheckCameraPermission()),
      child: const _ScannerCameraView(),
    );
  }
}

class _ScannerCameraView extends StatelessWidget {
  const _ScannerCameraView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chụp ảnh bài giảng & OCR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Quét chữ AI (OCR)',
            onPressed: () => context.push(Routes.ocrScanner),
          ),
        ],
      ),
      body: _buildCameraCaptureTab(context),
    );
  }

  Widget _buildCameraCaptureTab(BuildContext context) {
    return BlocBuilder<ScannerBloc, ScannerState>(
      builder: (context, state) {
        return Column(
          children: [
            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text(AppStrings.takePhoto),
                      onPressed: state.isProcessing
                          ? null
                          : () => context
                              .read<ScannerBloc>()
                              .add(const CapturePhotoRequested()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text(AppStrings.pickFromGallery),
                      onPressed: state.isProcessing
                          ? null
                          : () => context
                              .read<ScannerBloc>()
                              .add(const PickGalleryPhotoRequested()),
                    ),
                  ),
                ],
              ),
            ),

            if (state.isProcessing)
              const LinearProgressIndicator(),

            // Captured Images Grid
            Expanded(
              child: state.capturedImages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.noImagesCaptured,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: state.capturedImages.length,
                      itemBuilder: (context, index) {
                        final file = state.capturedImages[index];
                        return _buildImageCard(context, file, index);
                      },
                    ),
            ),

            // Bottom Action: Create Note from photos
            if (state.capturedImages.isNotEmpty)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.note_add),
                    label: const Text(AppStrings.createNoteFromImage),
                    onPressed: () {
                      final newNoteId = const Uuid().v4();
                      context.push(Routes.noteEdit(newNoteId));
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildImageCard(BuildContext context, File file, int index) {
    final sizeKb = (file.lengthSync() / 1024).toStringAsFixed(1);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(file, fit: BoxFit.cover),
          Positioned(
            top: 4,
            right: 4,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 18, color: Colors.white),
                onPressed: () {
                  context.read<ScannerBloc>().add(RemoveCapturedPhoto(index));
                },
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Ảnh #${index + 1} ($sizeKb KB)',
                style: const TextStyle(color: Colors.white, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
