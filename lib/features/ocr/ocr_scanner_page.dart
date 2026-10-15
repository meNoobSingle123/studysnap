import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

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
    final file = await _picker.pickImage(source: source);
    if (file == null) return;
    setState(() {
      _imagePath = file.path;
      _result = null;
      _error = null;
      _busy = true;
    });
    try {
      final r = await _service.recognize(file.path);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = 'Không nhận diện được: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nhận diện chữ (OCR)')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Nút chụp / chọn ảnh
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Chụp ảnh'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Thư viện'),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Ảnh preview
        if (_imagePath != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(File(_imagePath!),
                height: 220, fit: BoxFit.cover),
          ),

        // Trạng thái
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error!, style: TextStyle(color: cs.error)),
          ),

        // Kết quả
        if (r != null) ...[
          const SizedBox(height: 12),
          Text('Thời gian: ${r.elapsedMs} ms',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SelectableText(
              r.text.isEmpty ? '(Không thấy chữ trong ảnh)' : r.text),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Sao chép'),
              onPressed: () {
                HapticFeedback.lightImpact();
                Clipboard.setData(ClipboardData(text: r.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép!')),
                );
              },
            ),
            if (widget.onInsert != null) ...[
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  widget.onInsert!(r.text);
                  Navigator.pop(context);
                },
                child: const Text('Chèn vào ghi chú'),
              ),
            ],
          ]),
        ],
      ]),
    );
  }
}
