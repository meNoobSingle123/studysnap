import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/strings.dart';

// ── Model ──────────────────────────────────────────────────────────────────
class _OcrResult {
  final String text;
  final int elapsedMs;
  const _OcrResult(this.text, this.elapsedMs);
}

// ── Service ────────────────────────────────────────────────────────────────
class _OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<_OcrResult> recognize(String imagePath) async {
    final sw = Stopwatch()..start();
    final result =
        await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    sw.stop();
    return _OcrResult(result.text, sw.elapsedMilliseconds);
  }

  Future<void> close() => _recognizer.close();
}

// ── Page ───────────────────────────────────────────────────────────────────
/// Màn hình OCR (CĐ 12): nhận diện chữ in từ ảnh (không cần mạng).
/// [onInsert] — callback chèn chữ vào vị trí con trỏ trong NoteEditorPage (FR-14).
class OcrScannerPage extends StatefulWidget {
  final void Function(String text)? onInsert;
  const OcrScannerPage({super.key, this.onInsert});

  @override
  State<OcrScannerPage> createState() => _OcrScannerPageState();
}

class _OcrScannerPageState extends State<OcrScannerPage> {
  final _service = _OcrService();
  final _picker = ImagePicker();
  String? _imagePath;
  _OcrResult? _result;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.mobileOnlyFeature)),
        );
      }
      return;
    }

    final file = await _picker.pickImage(source: source);
    if (file == null) {
      return;
    }
    setState(() {
      _imagePath = file.path;
      _result = null;
      _error = null;
      _busy = true;
    });
    try {
      final r = await _service.recognize(file.path);
      if (mounted) {
        setState(() => _result = r);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '${AppStrings.ocrErrorPrefix}$e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.ocrTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── 1. Thẻ giới thiệu tính năng ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.document_scanner_rounded, color: cs.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhận diện chữ in ngoại tuyến (Offline OCR)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sử dụng ML Kit xử lý trực tiếp trên thiết bị, không cần mạng internet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 2. Nút chụp / chọn ảnh ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text(AppStrings.takePhoto),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text(AppStrings.ocrGallery),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── 3. Khung ảnh Preview hoặc Placeholder ──────────────────────────
          if (_imagePath != null && !kIsWeb) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Image.file(
                    File(_imagePath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Ảnh đã chọn',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!_busy) ...[
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_search_rounded,
                      size: 40,
                      color: cs.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chưa có ảnh nào được chọn',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bấm nút phía trên để chụp hoặc tải ảnh tài liệu lên',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── 4. Trạng thái xử lý ────────────────────────────────────────────
          if (_busy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Đang nhận diện văn bản bằng ML Kit...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_error != null)
            Card(
              color: cs.errorContainer,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(top: 16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: cs.onErrorContainer, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── 5. Thẻ kết quả nhận diện ───────────────────────────────────────
          if (r != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.text_snippet_rounded, color: cs.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Kết quả trích xuất',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${r.elapsedMs} ms',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        r.text.isEmpty ? AppStrings.ocrNoTextFound : r.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text(AppStrings.ocrCopy),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Clipboard.setData(ClipboardData(text: r.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(AppStrings.ocrCopied),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        if (widget.onInsert != null) ...[
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.check_rounded, size: 18),
                            onPressed: () {
                              widget.onInsert!(r.text);
                              Navigator.pop(context);
                            },
                            label: const Text(AppStrings.ocrInsertToNote),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
