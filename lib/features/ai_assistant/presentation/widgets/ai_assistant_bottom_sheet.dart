import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../notes/domain/repositories/note_repository.dart';
import '../bloc/ai_assistant_bloc.dart';
import '../bloc/ai_assistant_event.dart';
import '../bloc/ai_assistant_state.dart';

/// Modal Bottom Sheet cho Trợ lý Học tập AI.
/// Cung cấp 2 chế độ:
/// 1. Tóm tắt nội dung ghi chép thông minh.
/// 2. Tạo câu hỏi trắc nghiệm ôn tập (Active Recall).
class AiAssistantBottomSheet extends StatefulWidget {
  final String noteTitle;
  final String noteContent;
  final String? subjectName;
  final void Function(String textToInsert)? onInsertToNote;

  const AiAssistantBottomSheet({
    super.key,
    required this.noteTitle,
    required this.noteContent,
    this.subjectName,
    this.onInsertToNote,
  });

  static Future<void> show({
    required BuildContext context,
    required String noteTitle,
    required String noteContent,
    String? subjectName,
    void Function(String textToInsert)? onInsertToNote,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => getIt<AiAssistantBloc>()
          ..add(const CheckApiKeyStatus())
          ..add(SummarizeNoteRequested(
            title: noteTitle,
            content: noteContent,
            subjectName: subjectName,
          )),
        child: AiAssistantBottomSheet(
          noteTitle: noteTitle,
          noteContent: noteContent,
          subjectName: subjectName,
          onInsertToNote: onInsertToNote,
        ),
      ),
    );
  }

  @override
  State<AiAssistantBottomSheet> createState() => _AiAssistantBottomSheetState();
}

class _AiAssistantBottomSheetState extends State<AiAssistantBottomSheet> {
  int _selectedTab = 0; // 0: Tóm tắt, 1: Câu hỏi trắc nghiệm
  final TextEditingController _apiKeyController = TextEditingController();
  late String _currentTitle;
  late String _currentContent;
  String? _currentSubject;
  bool _isOcrProcessing = false;
  String? _ocrProgressText;

  // Cấu hình sinh trắc nghiệm
  int _quizCount = 5;
  String _quizDifficulty = 'Trung bình';

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.noteTitle.isNotEmpty ? widget.noteTitle : 'Tài liệu học tập';
    _currentContent = widget.noteContent;
    _currentSubject = widget.subjectName;
  }

  void _triggerAnalysis() {
    if (_selectedTab == 0) {
      context.read<AiAssistantBloc>().add(
            SummarizeNoteRequested(
              title: _currentTitle,
              content: _currentContent,
              subjectName: _currentSubject,
            ),
          );
    } else {
      context.read<AiAssistantBloc>().add(
            GenerateQuizRequested(
              title: _currentTitle,
              content: _currentContent,
              count: _quizCount,
              difficulty: _quizDifficulty,
            ),
          );
    }
  }

  /// Nạp nhiều ảnh slide bài giảng và chạy OCR offline ghép thành nội dung bài học
  Future<void> _pickSlideImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFiles.isEmpty || !mounted) return;

      setState(() {
        _isOcrProcessing = true;
        _ocrProgressText = 'Đang đọc slide 1/${pickedFiles.length}...';
      });

      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final buffer = StringBuffer();

      for (var i = 0; i < pickedFiles.length; i++) {
        if (!mounted) break;
        setState(() {
          _ocrProgressText = 'Đang đọc slide ${i + 1}/${pickedFiles.length}...';
        });
        final visionImage = InputImage.fromFilePath(pickedFiles[i].path);
        final recognizedText = await recognizer.processImage(visionImage);
        final pageText = recognizedText.text.trim();
        if (pageText.isNotEmpty) {
          buffer.writeln('=== Trang Slide ${i + 1} ===');
          buffer.writeln(pageText);
          buffer.writeln();
        }
      }
      await recognizer.close();

      if (!mounted) return;
      setState(() {
        _isOcrProcessing = false;
        _ocrProgressText = null;
      });

      final fullText = buffer.toString().trim();
      if (fullText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không nhận diện được nội dung trong các ảnh slide đã chọn.')),
        );
        return;
      }

      setState(() {
        _currentTitle = 'Slide bài giảng (${pickedFiles.length} trang)';
        _currentContent = fullText;
      });

      _triggerAnalysis();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nạp ${pickedFiles.length} trang slide (${fullText.length} ký tự) vào AI.'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOcrProcessing = false;
          _ocrProgressText = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi nạp slide bài giảng: $e')),
        );
      }
    }
  }

  Future<void> _pickNoteFromLibrary() async {
    try {
      final repo = getIt<NoteRepository>();
      final notes = await repo.getAllNotes();
      if (!mounted) return;

      if (notes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thư viện hiện chưa có ghi chú nào.')),
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.collections_bookmark_outlined, color: Color(0xFF5E48E8)),
                      const SizedBox(width: 8),
                      Text(
                        'Chọn bài học từ Thư viện (${notes.length})',
                        style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: notes.length,
                    itemBuilder: (ctx, i) {
                      final n = notes[i];
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(
                          n.title.isNotEmpty ? n.title : 'Ghi chú ${i + 1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          n.bodyText.isNotEmpty
                              ? n.bodyText
                              : 'Chưa có nội dung văn bản',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          setState(() {
                            _currentTitle = n.title.isNotEmpty ? n.title : 'Ghi chú';
                            _currentContent = n.bodyText.isNotEmpty
                                ? n.bodyText
                                : 'Bài học ${n.title}';
                            _currentSubject = n.subjectId;
                          });
                          _triggerAnalysis();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _scanDocumentOcr(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _isOcrProcessing = true);

      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final visionImage = InputImage.fromFilePath(picked.path);
      final recognizedText = await recognizer.processImage(visionImage);
      await recognizer.close();

      if (!mounted) return;
      setState(() => _isOcrProcessing = false);

      final text = recognizedText.text.trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không nhận diện được chữ trong ảnh.')),
        );
        return;
      }

      setState(() {
        _currentTitle = 'Tài liệu quét ảnh OCR';
        _currentContent = text;
      });

      _triggerAnalysis();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nhận diện ${text.length} ký tự từ ảnh và nạp vào AI.'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isOcrProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi quét ảnh OCR: $e')),
        );
      }
    }
  }

  Future<void> _editContentDirectly() async {
    final titleCtrl = TextEditingController(text: _currentTitle);
    final contentCtrl = TextEditingController(text: _currentContent);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Nhập/Dán nội dung bài học'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề bài học',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Nội dung bài học / Giáo trình',
                  hintText: 'Dán nội dung cần tóm tắt hoặc tạo trắc nghiệm...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Áp dụng & Phân tích'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      setState(() {
        _currentTitle = titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Bài học';
        _currentContent = contentCtrl.text.trim();
      });
      _triggerAnalysis();
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Handle bar ───────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header Title & Close ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trợ lý Học tập AI',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _currentTitle.isNotEmpty
                                ? _currentTitle
                                : 'Bài giảng hiện tại',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── Thanh Chọn Nguồn Tài liệu (Slide / Quét ảnh OCR / Thư viện / Sửa dán) ─
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.slideshow_rounded, size: 16, color: Color(0xFF5E48E8)),
                        label: Text(
                          _ocrProgressText ?? '📑 Nạp Slide (${_currentTitle.contains('Slide') ? 'Đã nạp' : 'Nhiều ảnh'})',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: _isOcrProcessing ? null : _pickSlideImages,
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.document_scanner_outlined, size: 16, color: Colors.teal),
                        label: Text(
                          _isOcrProcessing && _ocrProgressText == null ? 'Đang quét...' : 'Quét ảnh OCR',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: _isOcrProcessing
                            ? null
                            : () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  builder: (ctx) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.camera_alt_outlined),
                                          title: const Text('Chụp ảnh tài liệu/bảng viết'),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            _scanDocumentOcr(ImageSource.camera);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.photo_library_outlined),
                                          title: const Text('Chọn 1 ảnh từ Thư viện'),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            _scanDocumentOcr(ImageSource.gallery);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.collections_bookmark_outlined, size: 16, color: Colors.indigo),
                        label: const Text('Từ ghi chú', style: TextStyle(fontSize: 11.5)),
                        visualDensity: VisualDensity.compact,
                        onPressed: _pickNoteFromLibrary,
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Sửa / Dán', style: TextStyle(fontSize: 11.5)),
                        visualDensity: VisualDensity.compact,
                        onPressed: _editContentDirectly,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Segmented Control (Tóm tắt / Trắc nghiệm) ───────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.notes_rounded),
                      label: Text('Tóm tắt bài học'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.quiz_outlined),
                      label: Text('Câu hỏi trắc nghiệm'),
                    ),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (set) {
                    final newTab = set.first;
                    setState(() => _selectedTab = newTab);
                    _triggerAnalysis();
                  },
                ),
              ),

              const Divider(height: 1),

              // ── Dynamic Body State ───────────────────────────────────────
              Expanded(
                child: BlocBuilder<AiAssistantBloc, AiAssistantState>(
                  builder: (context, state) {
                    if (state is AiAssistantLoading) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                state.message,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (state is AiAssistantNeedsApiKey) {
                      return _buildApiKeySetupView(context, state.existingKey);
                    }

                    if (state is AiAssistantFailure) {
                      return _buildErrorView(context, state);
                    }

                    if (state is AiAssistantSummarySuccess) {
                      return _buildSummaryView(context, state, scrollController);
                    }

                    if (state is AiAssistantQuizSuccess) {
                      return _buildQuizView(context, state, scrollController);
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 1. Màn hình cấu hình API Key ──────────────────────────────────────────
  Widget _buildApiKeySetupView(BuildContext context, String? existingKey) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_rounded, color: colorScheme.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Cấu hình Khóa API AI',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Khóa API AI đã được hệ thống cấu hình sẵn. Bạn có thể cập nhật khóa mới nếu muốn tùy chỉnh riêng.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Nhập Khóa API AI',
              hintText: 'AIzaSy...',
              prefixIcon: const Icon(Icons.password_rounded),
              suffixIcon: IconButton(
                tooltip: 'Dán từ bộ nhớ tạm',
                icon: const Icon(Icons.paste_rounded),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _apiKeyController.text = data!.text!.trim();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final text = _apiKeyController.text.trim();
                    if (text.isNotEmpty) {
                      context
                          .read<AiAssistantBloc>()
                          .add(SaveApiKeyRequested(text));
                      // Kích hoạt lại yêu cầu hiện tại
                      _triggerAnalysis();
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Lưu & Bắt đầu phân tích'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lấy API Key hoàn toàn miễn phí tại: aistudio.google.com/app/apikey',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Màn hình lỗi & Thử lại ────────────────────────────────────────────
  Widget _buildErrorView(BuildContext context, AiAssistantFailure state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: colorScheme.error, size: 48),
            const SizedBox(height: 12),
            Text(
              'Không thể hoàn thành yêu cầu',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.isApiKeyError) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      context
                          .read<AiAssistantBloc>()
                          .add(const CheckApiKeyStatus());
                    },
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Cài lại API Key'),
                  ),
                  const SizedBox(width: 12),
                ],
                FilledButton.icon(
                  onPressed: _triggerAnalysis,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Màn hình xem bản tóm tắt bài học ───────────────────────────────────
  Widget _buildSummaryView(
    BuildContext context,
    AiAssistantSummarySuccess state,
    ScrollController scrollController,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = state.summary;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Tổng quan
        Card(
          elevation: 0,
          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_rounded,
                        color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'TỔNG QUAN BÀI GIẢNG',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  summary.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Các ý chính cốt lõi
        if (summary.keyPoints.isNotEmpty) ...[
          Text(
            'Ý chính quan trọng',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...summary.keyPoints.map((point) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],

        // Lời khuyên ôn thi / Thực hành
        if (summary.practicalTakeaways.isNotEmpty) ...[
          Text(
            'Mẹo ôn thi & Ghi nhớ nhanh',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...summary.practicalTakeaways.map((tip) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // ── Action Buttons (Sao chép & Chèn vào ghi chú) ───────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: summary.toMarkdown()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép nội dung tóm tắt.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Sao chép'),
              ),
            ),
            if (widget.onInsertToNote != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    widget.onInsertToNote!(summary.toMarkdown());
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã chèn tóm tắt AI vào cuối bài ghi chú.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_task_rounded, size: 18),
                  label: const Text('Chèn vào bài'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ── 4. Màn hình Câu hỏi trắc nghiệm ôn tập (Active Recall) ─────────────────
  Widget _buildQuizView(
    BuildContext context,
    AiAssistantQuizSuccess state,
    ScrollController scrollController,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final questions = state.questions;
    final answeredCount = state.userAnswers.length;
    final isCompleted = answeredCount == questions.length && questions.isNotEmpty;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // ── Thanh Tùy chọn Bộ đề Trắc nghiệm (Mức độ đề & Số câu) ──────
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 18, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Cấu hình bộ trắc nghiệm',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: _triggerAnalysis,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Tạo lại', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Chọn số lượng câu hỏi
                Row(
                  children: [
                    Text(
                      'Số câu:',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: [3, 5, 10].map((count) {
                          final isSelected = _quizCount == count;
                          return ChoiceChip(
                            label: Text('$count câu', style: const TextStyle(fontSize: 11.5)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _quizCount = count);
                                _triggerAnalysis();
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Chọn mức độ đề
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Mức độ:',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          {'key': 'Dễ', 'label': 'Dễ (Nhận biết)'},
                          {'key': 'Trung bình', 'label': 'Trung bình (Thông hiểu)'},
                          {'key': 'Khó', 'label': 'Khó (Vận dụng cao)'},
                        ].map((m) {
                          final key = m['key']!;
                          final label = m['label']!;
                          final isSelected = _quizDifficulty == key;
                          return ChoiceChip(
                            label: Text(label, style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _quizDifficulty = key);
                                _triggerAnalysis();
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Bảng kết quả điểm số
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.verified_rounded
                      : Icons.help_center_outlined,
                  color: isCompleted ? Colors.green : colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCompleted
                            ? 'Kết quả: ${state.correctCount}/${questions.length} câu đúng'
                            : 'Đã trả lời $answeredCount/${questions.length} câu',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCompleted
                            ? (state.correctCount == questions.length
                                ? 'Xuất sắc! Bạn đã nắm vững bài học 🎉'
                                : 'Hãy xem lại phần giải thích bên dưới để ôn thi.')
                            : 'Chọn đáp án để tự kiểm tra kiến thức (Active Recall).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Danh sách câu hỏi
        ...questions.asMap().entries.map((entry) {
          final qIndex = entry.key;
          final q = entry.value;
          final selectedOption = state.userAnswers[q.id];
          final isAnswered = selectedOption != null;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isAnswered
                    ? (selectedOption == q.correctOptionIndex
                        ? Colors.green.withValues(alpha: 0.5)
                        : colorScheme.error.withValues(alpha: 0.5))
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Câu ${qIndex + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.question,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4 Options
                  ...q.options.asMap().entries.map((optEntry) {
                    final optIndex = optEntry.key;
                    final optText = optEntry.value;

                    Color tileColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
                    Color borderColor = Colors.transparent;

                    if (isAnswered) {
                      if (optIndex == q.correctOptionIndex) {
                        tileColor = Colors.green.withValues(alpha: 0.15);
                        borderColor = Colors.green;
                      } else if (optIndex == selectedOption) {
                        tileColor = colorScheme.error.withValues(alpha: 0.15);
                        borderColor = colorScheme.error;
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: tileColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          context.read<AiAssistantBloc>().add(
                                AnswerSelected(
                                  questionId: q.id,
                                  selectedIndex: optIndex,
                                ),
                              );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Text(
                                '${String.fromCharCode(65 + optIndex)}. ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isAnswered &&
                                          optIndex == q.correctOptionIndex
                                      ? Colors.green.shade800
                                      : colorScheme.onSurface,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  optText,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              if (isAnswered && optIndex == q.correctOptionIndex)
                                const Icon(Icons.check_circle_rounded,
                                    color: Colors.green, size: 18)
                              else if (isAnswered && optIndex == selectedOption)
                                Icon(Icons.cancel_rounded,
                                    color: colorScheme.error, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // Giải thích khi đã trả lời
                  if (isAnswered && q.explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              size: 16, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Giải thích: ${q.explanation}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),

        // Nút sinh lại câu hỏi theo cấu hình hiện tại
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _triggerAnalysis,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Sinh lại bộ câu hỏi trắc nghiệm'),
        ),
      ],
    );
  }
}

