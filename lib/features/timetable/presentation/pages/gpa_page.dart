import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../domain/entities/subject.dart';
import '../../domain/repositories/timetable_repository.dart';
import '../../domain/usecases/calculate_gpa_usecase.dart';
import '../bloc/gpa_bloc.dart';

class GpaPage extends StatelessWidget {
  const GpaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GpaBloc(
        calculateGpaUseCase: getIt<CalculateGpaUseCase>(),
      ),
      child: const _GpaView(),
    );
  }
}

class _GpaView extends StatefulWidget {
  const _GpaView();

  @override
  State<_GpaView> createState() => _GpaViewState();
}

class _GpaViewState extends State<_GpaView> {
  late final TextEditingController _currentGpaController;
  late final TextEditingController _completedCreditsController;
  late final TextEditingController _remainingCreditsController;
  List<Subject> _subjects = [];
  bool _isLoadingSubjects = true;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<GpaBloc>();
    _currentGpaController =
        TextEditingController(text: bloc.state.currentGpa.toString());
    _completedCreditsController =
        TextEditingController(text: bloc.state.completedCredits.toString());
    _remainingCreditsController =
        TextEditingController(text: bloc.state.remainingCredits.toString());
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    if (getIt.isRegistered<TimetableRepository>()) {
      try {
        final subs = await getIt<TimetableRepository>().getSubjects();
        if (mounted) {
          setState(() {
            _subjects = subs.where((s) => !s.isDeleted).toList();
            _isLoadingSubjects = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingSubjects = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingSubjects = false);
    }
  }

  void _calculateFromRealSubjects() {
    final withGrade = _subjects.where((s) => s.gradePoint != null).toList();
    final withoutGrade = _subjects.where((s) => s.gradePoint == null).toList();

    if (withGrade.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có môn nào được nhập điểm! Chạm vào môn để nhập điểm hoặc nhấn "+ Thêm môn".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    int completed = 0;
    double totalPoints = 0.0;
    for (final s in withGrade) {
      completed += s.credits;
      totalPoints += (s.gradePoint! * s.credits);
    }

    int remaining = 0;
    for (final s in withoutGrade) {
      remaining += s.credits;
    }
    // Giữ nguyên số tín chỉ còn lại do người dùng nhập nếu không có môn chưa học
    if (remaining == 0) {
      remaining = int.tryParse(_remainingCreditsController.text.trim()) ?? 0;
    }

    final realGpa = completed > 0
        ? double.parse((totalPoints / completed).toStringAsFixed(2))
        : 3.0;

    _currentGpaController.text = realGpa.toString();
    _completedCreditsController.text = completed.toString();
    _remainingCreditsController.text = remaining.toString();

    context.read<GpaBloc>().add(GpaCurrentChanged(realGpa));
    context.read<GpaBloc>().add(GpaCompletedCreditsChanged(completed));
    context.read<GpaBloc>().add(GpaRemainingCreditsChanged(remaining));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã cập nhật GPA $realGpa từ ${withGrade.length} môn học thực tế!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showAddSubjectModal() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final creditsCtrl = TextEditingController(text: '3');
    double selectedGrade = 3.0;

    final gradesMap = {
      4.0: 'A+ (4.0) - Xuất sắc',
      3.7: 'A  (3.7) - Giỏi',
      3.5: 'B+ (3.5) - Khá giỏi',
      3.0: 'B  (3.0) - Khá',
      2.5: 'C+ (2.5) - Trung bình khá',
      2.0: 'C  (2.0) - Trung bình',
      1.5: 'D+ (1.5) - Trung bình yếu',
      1.0: 'D  (1.0) - Yếu',
      0.0: 'F  (0.0) - Kém / Trượt môn',
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Thêm môn học & điểm'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên môn học',
                    hintText: 'VD: Toán cao cấp',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mã môn',
                          hintText: 'MATH101',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: creditsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số tín chỉ',
                          hintText: '3',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<double>(
                  initialValue: selectedGrade,
                  decoration: const InputDecoration(labelText: 'Điểm tổng kết (hệ 4)'),
                  items: gradesMap.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedGrade = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim().isEmpty ? 'SUB' : codeCtrl.text.trim().toUpperCase();
                final credits = int.tryParse(creditsCtrl.text.trim()) ?? 3;
                if (name.isEmpty) return;

                final newSubject = Subject(
                  id: 'subj_${DateTime.now().millisecondsSinceEpoch}',
                  code: code,
                  name: name,
                  credits: credits > 0 ? credits : 1,
                  colorArgb: 0xFF1E88E5,
                  gradePoint: selectedGrade,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                if (getIt.isRegistered<TimetableRepository>()) {
                  await getIt<TimetableRepository>().saveSubject(newSubject);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadSubjects();
                _calculateFromRealSubjects();
              },
              child: const Text('Thêm môn'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditGradeModal(Subject subject) async {
    double selectedGrade = subject.gradePoint ?? 3.0;
    final gradesMap = {
      4.0: 'A+ (4.0) - Xuất sắc',
      3.7: 'A  (3.7) - Giỏi',
      3.5: 'B+ (3.5) - Khá giỏi',
      3.0: 'B  (3.0) - Khá',
      2.5: 'C+ (2.5) - Trung bình khá',
      2.0: 'C  (2.0) - Trung bình',
      1.5: 'D+ (1.5) - Trung bình yếu',
      1.0: 'D  (1.0) - Yếu',
      0.0: 'F  (0.0) - Kém / Trượt môn',
    };

    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Điểm môn: ${subject.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mã môn: ${subject.code} • Số tín chỉ: ${subject.credits}',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 14),
                  const Text('Chọn mức điểm hệ 4:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<double>(
                    initialValue: gradesMap.containsKey(selectedGrade) ? selectedGrade : 3.0,
                    isExpanded: true,
                    items: gradesMap.entries.map((entry) {
                      return DropdownMenuItem<double>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedGrade = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                if (subject.gradePoint != null)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, -1.0),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Xóa điểm'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selectedGrade),
                  child: const Text('Lưu điểm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      final updated = subject.copyWith(
        gradePoint: result >= 0 ? result : null,
        clearGrade: result < 0,
      );
      if (getIt.isRegistered<TimetableRepository>()) {
        await getIt<TimetableRepository>().saveSubject(updated);
      }
      await _loadSubjects();
      _calculateFromRealSubjects();
    }
  }

  @override
  void dispose() {
    _currentGpaController.dispose();
    _completedCreditsController.dispose();
    _remainingCreditsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.gpaProjectionTitle),
      ),
      body: BlocBuilder<GpaBloc, GpaState>(
        builder: (context, state) {
          final result = state.result;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Thẻ kết quả hiển thị nổi bật ở trên cùng
                _buildResultCard(context, result, state),

                const SizedBox(height: 16),

                // 2. Nhóm trường nhập dữ liệu số
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.school_rounded,
                                color: colorScheme.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Thông tin học tập',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _calculateFromRealSubjects,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.auto_awesome, size: 15),
                              label: const Text('Tự tính', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // GPA hiện tại
                        TextField(
                          controller: _currentGpaController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: AppStrings.currentGpa,
                            hintText: 'VD: 3.2',
                            prefixIcon: const Icon(Icons.grade_rounded),
                            suffixText: '/ 4.0',
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            final cleaned = val.replaceAll(',', '.').trim();
                            final d = double.tryParse(cleaned);
                            if (d != null) {
                              context.read<GpaBloc>().add(GpaCurrentChanged(d));
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            // Tín chỉ đã tích lũy
                            Expanded(
                              child: TextField(
                                controller: _completedCreditsController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'TC tích lũy',
                                  hintText: '60',
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                onChanged: (val) {
                                  final i = int.tryParse(val.trim());
                                  if (i != null) {
                                    context
                                        .read<GpaBloc>()
                                        .add(GpaCompletedCreditsChanged(i));
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Tín chỉ còn lại
                            Expanded(
                              child: TextField(
                                controller: _remainingCreditsController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'TC còn lại',
                                  hintText: '30',
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                onChanged: (val) {
                                  final i = int.tryParse(val.trim());
                                  if (i != null) {
                                    context
                                        .read<GpaBloc>()
                                        .add(GpaRemainingCreditsChanged(i));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Thanh trượt chọn GPA mục tiêu (Chủ đề 2)
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
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
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.flag_rounded,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  AppStrings.targetGpa,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                '${state.targetGpa.toStringAsFixed(2)} / 4.0',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Slider chọn từ 0.0 đến 4.0 (bước 0.05)
                        Slider(
                          value: state.targetGpa,
                          min: 0.0,
                          max: 4.0,
                          divisions: 80,
                          label: state.targetGpa.toStringAsFixed(2),
                          onChanged: (val) {
                            context.read<GpaBloc>().add(GpaTargetChanged(val));
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('0.0 (Yếu)', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                              Text('2.5 (Khá)', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                              Text('3.2 (Giỏi)', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                              Text('4.0 (Xuất sắc)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Bảng điểm môn học chi tiết (Dữ liệu thực tế)
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.teal,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bảng điểm môn học',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _showAddSubjectModal,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Thêm môn', style: TextStyle(fontSize: 12)),
                            ),
                            IconButton(
                              tooltip: 'Tính lại GPA',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              onPressed: _calculateFromRealSubjects,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Chạm vào môn học để nhập/sửa điểm (hệ 4 / chữ). Hệ thống sẽ tự tổng hợp điểm GPA tích lũy.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingSubjects)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (_subjects.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Text(
                                  'Chưa có môn học nào trong danh sách.',
                                  style: TextStyle(color: colorScheme.outline),
                                ),
                                const SizedBox(height: 10),
                                FilledButton.tonalIcon(
                                  onPressed: _showAddSubjectModal,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Thêm môn học đầu tiên'),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _subjects.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final sub = _subjects[index];
                              final hasGrade = sub.gradePoint != null;
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Color(sub.colorArgb).withValues(alpha: 0.2),
                                  child: Text(
                                    sub.code.isNotEmpty ? sub.code[0] : 'M',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(sub.colorArgb),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  sub.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                subtitle: Text(
                                  'Mã: ${sub.code} • ${sub.credits} tín chỉ',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: hasGrade
                                        ? colorScheme.primaryContainer
                                        : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    hasGrade
                                        ? '${sub.gradePoint!.toStringAsFixed(2)} (${sub.letterGrade})'
                                        : 'Nhập điểm',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: hasGrade
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.outline,
                                    ),
                                  ),
                                ),
                                onTap: () => _showEditGradeModal(sub),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    GpaProjectionResult? result,
    GpaState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (result == null) return const SizedBox.shrink();

    Color cardBg;
    Color textColor;
    IconData icon;
    String statusTitle;
    String detailMessage;

    switch (result.status) {
      case GpaProjectionStatus.achievable:
        cardBg = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        icon = Icons.trending_up_rounded;
        statusTitle = 'MỤC TIÊU KHẢ THI';
        detailMessage =
            'Để đạt GPA mục tiêu ${state.targetGpa.toStringAsFixed(2)}, bạn cần đạt điểm trung bình tối thiểu ${result.requiredGpa.toStringAsFixed(2)} / 4.0 cho ${state.remainingCredits} tín chỉ còn lại.';
      case GpaProjectionStatus.alreadyAchieved:
        cardBg = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = Icons.emoji_events_rounded;
        statusTitle = 'ĐÃ ĐẠT MỤC TIÊU!';
        detailMessage =
            'GPA hiện tại của bạn (${state.currentGpa.toStringAsFixed(2)}) đã đạt hoặc vượt mục tiêu (${state.targetGpa.toStringAsFixed(2)}). Tiếp tục duy trì phong độ nhé!';
      case GpaProjectionStatus.impossible:
        cardBg = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        icon = Icons.warning_amber_rounded;
        statusTitle = 'MỤC TIÊU CHƯA KHẢ THI';
        detailMessage =
            'Cần đạt ${result.requiredGpa.toStringAsFixed(2)} / 4.0 (vượt quá mức tối đa 4.0). Bạn hãy đăng ký thêm tín chỉ hoặc điều chỉnh nhẹ mục tiêu GPA.';
      case GpaProjectionStatus.invalidInput:
        cardBg = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        icon = Icons.info_outline_rounded;
        statusTitle = 'THÔNG TIN CHƯA HỢP LỆ';
        detailMessage = result.message;
    }

    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: textColor),
                const SizedBox(width: 8),
                Text(
                  statusTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              detailMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.35,
              ),
            ),
            if (result.status == GpaProjectionStatus.achievable) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Điểm cần đạt tối thiểu:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${result.requiredGpa.toStringAsFixed(2)} / 4.0',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
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
  }
}
