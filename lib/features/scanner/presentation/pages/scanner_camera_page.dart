import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../domain/entities/qr_document_link.dart';
import '../../domain/usecases/parse_qr_code_usecase.dart';
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

class _ScannerCameraView extends StatefulWidget {
  const _ScannerCameraView();

  @override
  State<_ScannerCameraView> createState() => _ScannerCameraViewState();
}

class _ScannerCameraViewState extends State<_ScannerCameraView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleValidQrLink(
    BuildContext context,
    QrDocumentLink link,
  ) async {
    final connectivityResults = await Connectivity().checkConnectivity();
    final hasConnection =
        !connectivityResults.contains(ConnectivityResult.none);

    if (!context.mounted) return;

    if (!hasConnection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.needNetworkConnection),
          backgroundColor: Colors.orange,
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text(AppStrings.qrDocumentConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppStrings.qrDocumentConfirmMessage),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                link.domain,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              link.documentUrl,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<ScannerBloc>().add(const ClearQrResult());
            },
            child: const Text(AppStrings.cancel),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_browser),
            label: const Text(AppStrings.openInBrowser),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              context.read<ScannerBloc>().add(const ClearQrResult());
              final uri = Uri.parse(link.documentUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScannerBloc, ScannerState>(
      listenWhen: (prev, curr) => prev.qrResult != curr.qrResult,
      listener: (context, state) {
        final result = state.qrResult;
        if (result is QrParseSuccess) {
          _handleValidQrLink(context, result.link);
        } else if (result is QrParseFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: AppStrings.ok,
                textColor: Colors.white,
                onPressed: () {
                  context.read<ScannerBloc>().add(const ClearQrResult());
                },
              ),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.scannerTitle),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.qr_code_scanner),
                text: AppStrings.qrScannerTab,
              ),
              Tab(
                icon: Icon(Icons.camera_alt_outlined),
                text: AppStrings.cameraCaptureTab,
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildQrScannerTab(context),
            _buildCameraCaptureTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQrScannerTab(BuildContext context) {
    return BlocBuilder<ScannerBloc, ScannerState>(
      builder: (context, state) {
        if (!state.hasCameraPermission) {
          return _buildPermissionDeniedGuide(context, state);
        }

        return Stack(
          children: [
            // Scanner Viewfinder
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final barcode = capture.barcodes.firstOrNull;
                if (barcode != null && barcode.rawValue != null) {
                  context
                      .read<ScannerBloc>()
                      .add(QrCodeScanned(barcode.rawValue!));
                }
              },
            ),

            // Top overlay prompt
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.black.withValues(alpha: 0.65),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.scanQrPrompt,
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Scanner Controls (Flash & Switch Camera)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.flash_on),
                    onPressed: () => _scannerController.toggleTorch(),
                  ),
                  const SizedBox(width: 24),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.cameraswitch),
                    onPressed: () => _scannerController.switchCamera(),
                  ),
                ],
              ),
            ),

            // Bottom Simulator Bar for testing on Emulators
            Positioned(
              bottom: 8,
              left: 12,
              right: 12,
              child: _buildTestQrCodeChips(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTestQrCodeChips(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.testSampleQrCodes,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                    label: const Text(AppStrings.sampleValidQr1),
                    onPressed: () {
                      context.read<ScannerBloc>().add(
                            const QrCodeScanned(
                              'studysnap://doc?url=https%3A%2F%2Ffit.hcmus.edu.vn%2Fsyllabus.pdf',
                            ),
                          );
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                    label: const Text(AppStrings.sampleValidQr2),
                    onPressed: () {
                      context.read<ScannerBloc>().add(
                            const QrCodeScanned(
                              'studysnap://doc?url=https%3A%2F%2Fdrive.google.com%2Ffile%2Fd%2Fexample_lecture_slides.pdf',
                            ),
                          );
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                    label: const Text(AppStrings.sampleInvalidHttp),
                    onPressed: () {
                      context.read<ScannerBloc>().add(
                            const QrCodeScanned(
                              'studysnap://doc?url=http%3A%2F%2Finsecure-domain.com%2Fdoc',
                            ),
                          );
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                    label: const Text(AppStrings.sampleInvalidScheme),
                    onPressed: () {
                      context.read<ScannerBloc>().add(
                            const QrCodeScanned('otherapp://open?file=secret'),
                          );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedGuide(BuildContext context, ScannerState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.cameraPermissionRequired,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.cameraPermissionGuide,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    context
                        .read<ScannerBloc>()
                        .add(const RequestCameraPermission());
                  },
                  child: const Text('Thử lại'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text(AppStrings.openAppSettings),
                  onPressed: () => openAppSettings(),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Simulator can still be tested even without real camera permission
            _buildTestQrCodeChips(context),
          ],
        ),
      ),
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
