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
  static final Map<double, String> _gradesMap = {
    4.0: 'A+ (4.0) - Xuất sắc',
    3.7: 'A  (3.7) - Giỏi',
    3.5: 'B+ (3.5) - Khá giỏi',
    3.0: 'B  (3.0) - Khá',
    2.5: 'C+ (2.5) - Trung bình khá',
    2.0: 'C  (2.0) - Trung bình',
    1.5: 'D+ (1.5) - Trung bình yếu',
    1.0: 'D  (1.0) - Yếu',
    0.0: 'F  (0.0) - Kém / Học lại',
  };

  late final TextEditingController _currentGpaController;
  late final TextEditingController _completedCreditsController;
  late final TextEditingController _remainingCreditsController;

  List<Subject> _subjects = [];
  bool _isLoadingSubjects = true;

  String? _currentGpaError;
  String? _completedCreditsError;
  String? _remainingCreditsError;

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

  @override
  void dispose() {
    _currentGpaController.dispose();
    _completedCreditsController.dispose();
    _remainingCreditsController.dispose();
    super.dispose();
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

  String _rankLabel(double gpa) {
    if (gpa >= 3.6) return 'Xuất sắc';
    if (gpa >= 3.2) return 'Giỏi';
    if (gpa >= 2.5) return 'Khá';
    if (gpa >= 2.0) return 'Trung bình';
    return 'Cần cố gắng';
  }

  String _equivalentLetterHint(double requiredGpa) {
    if (requiredGpa >= 3.85) return 'mức A+ (gần như tuyệt đối mọi môn)';
    if (requiredGpa >= 3.60) return 'mức A (từ 3.7 trở lên)';
    if (requiredGpa >= 3.25) return 'mức B+ đến A (khoảng 3.5)';
    if (requiredGpa >= 2.75) return 'mức B (khoảng 3.0)';
    if (requiredGpa >= 2.25) return 'mức C+ (khoảng 2.5)';
    if (requiredGpa >= 1.75) return 'mức C (khoảng 2.0)';
    if (requiredGpa >= 1.0) return 'mức D (chỉ cần qua môn an toàn)';
    return 'rất nhẹ nhàng (qua môn là đạt)';
  }

  void _onCurrentGpaChanged(String val) {
    final cleaned = val.replaceAll(',', '.').trim();
    if (cleaned.isEmpty) {
      setState(() => _currentGpaError = 'Vui lòng nhập GPA (0.0 - 4.0)');
      return;
    }
    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      setState(() => _currentGpaError = 'Chỉ nhập số thập phân (VD: 3.15)');
      return;
    }
    if (parsed < 0 || parsed > 4.0) {
      setState(() => _currentGpaError = 'GPA hệ 4 phải từ 0.0 đến 4.0');
      context.read<GpaBloc>().add(GpaCurrentChanged(parsed));
      return;
    }
    setState(() => _currentGpaError = null);
    context.read<GpaBloc>().add(GpaCurrentChanged(parsed));
  }

  void _onCompletedCreditsChanged(String val) {
    final cleaned = val.trim();
    if (cleaned.isEmpty) {
      setState(() => _completedCreditsError = 'Nhập số TC đã học');
      return;
    }
    final parsed = int.tryParse(cleaned);
    if (parsed == null || parsed < 0) {
      setState(() => _completedCreditsError = 'Nhập số nguyên >= 0');
      if (parsed != null) {
        context.read<GpaBloc>().add(GpaCompletedCreditsChanged(parsed));
      }
      return;
    }
    setState(() => _completedCreditsError = null);
    context.read<GpaBloc>().add(GpaCompletedCreditsChanged(parsed));
  }

  void _onRemainingCreditsChanged(String val) {
    final cleaned = val.trim();
    if (cleaned.isEmpty) {
      setState(() => _remainingCreditsError = 'Nhập số TC còn lại');
      return;
    }
    final parsed = int.tryParse(cleaned);
    if (parsed == null || parsed < 0) {
      setState(() => _remainingCreditsError = 'Nhập số nguyên >= 0');
      if (parsed != null) {
        context.read<GpaBloc>().add(GpaRemainingCreditsChanged(parsed));
      }
      return;
    }
    setState(() => _remainingCreditsError = null);
    context.read<GpaBloc>().add(GpaRemainingCreditsChanged(parsed));
  }

  void _calculateFromRealSubjects() {
    final withGrade = _subjects.where((s) => s.gradePoint != null).toList();
    final withoutGrade = _subjects.where((s) => s.gradePoint == null).toList();

    if (withGrade.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa có môn nào được nhập điểm. Hãy chạm vào từng môn ở mục 3 bên dưới hoặc bấm "+ Thêm môn".',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    int completed = 0;
    double totalPoints = 0.0;
    for (final s in withGrade) {
      final gp = s.gradePoint;
      if (gp == null) continue;
      completed += s.credits;
      totalPoints += gp * s.credits;
    }

    int remaining = 0;
    for (final s in withoutGrade) {
      remaining += s.credits;
    }
    if (remaining == 0) {
      final manualRemaining =
          int.tryParse(_remainingCreditsController.text.trim());
      remaining = (manualRemaining != null && manualRemaining >= 0)
          ? manualRemaining
          : 0;
    }

    final realGpa = completed > 0
        ? double.parse((totalPoints / completed).toStringAsFixed(2))
        : 0.0;

    setState(() {
      _currentGpaError = null;
      _completedCreditsError = null;
      _remainingCreditsError = null;
      _currentGpaController.text = realGpa.toStringAsFixed(2);
      _completedCreditsController.text = completed.toString();
      _remainingCreditsController.text = remaining.toString();
    });

    context.read<GpaBloc>().add(GpaCurrentChanged(realGpa));
    context.read<GpaBloc>().add(GpaCompletedCreditsChanged(completed));
    context.read<GpaBloc>().add(GpaRemainingCreditsChanged(remaining));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã lấy GPA ${realGpa.toStringAsFixed(2)} ($completed TC) từ ${withGrade.length} môn học!',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future<void> _showHelpDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded),
            SizedBox(width: 8),
            Expanded(child: Text('Cách dùng Tính điểm GPA')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ứng dụng giúp bạn biết các tín chỉ sắp tới cần đạt trung bình bao nhiêu điểm để kịp đạt GPA mục tiêu.',
                style: TextStyle(height: 1.4),
              ),
              SizedBox(height: 12),
              Text('• GPA đã có: Điểm TB tích lũy hiện tại (thang 4.0).',
                  style: TextStyle(fontSize: 13, height: 1.35)),
              SizedBox(height: 4),
              Text('• Tín chỉ đã tích lũy: Tổng tín chỉ của các môn đã có điểm.',
                  style: TextStyle(fontSize: 13, height: 1.35)),
              SizedBox(height: 4),
              Text('• Tín chỉ sắp học: Số tín chỉ kỳ tới hoặc đến lúc tốt nghiệp.',
                  style: TextStyle(fontSize: 13, height: 1.35)),
              SizedBox(height: 12),
              Text(
                'Ví dụ dễ hiểu:\nBạn đang có GPA 3.0 (60 TC), còn 30 TC nữa ra trường và muốn tổng kết đạt 3.2 (bằng Giỏi) → 30 TC còn lại cần đạt TB 3.60/4.0 (khoảng mức A).',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSubjectModal() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final creditsCtrl = TextEditingController(text: '3');
    double selectedGrade = 3.0;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Thêm môn học & điểm'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên môn học *',
                      hintText: 'VD: Toán cao cấp',
                      prefixIcon: Icon(Icons.book_outlined),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Vui lòng nhập tên môn học'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mã môn',
                            hintText: 'MATH101',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: creditsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số tín chỉ *',
                            hintText: '3',
                          ),
                          validator: (val) {
                            final c = int.tryParse((val ?? '').trim());
                            if (c == null || c <= 0) {
                              return 'TC > 0';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<double>(
                    initialValue: selectedGrade,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Điểm tổng kết (hệ 4)'),
                    items: _gradesMap.entries
                        .map((e) =>
                            DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedGrade = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim().isEmpty
                    ? 'SUB'
                    : codeCtrl.text.trim().toUpperCase();
                final credits = int.tryParse(creditsCtrl.text.trim()) ?? 3;

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

    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Điểm môn: ${subject.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mã môn: ${subject.code} • ${subject.credits} tín chỉ',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    const Text('Chọn điểm tổng kết (hệ 4):'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<double>(
                      initialValue: _gradesMap.containsKey(selectedGrade)
                          ? selectedGrade
                          : 3.0,
                      isExpanded: true,
                      items: _gradesMap.entries.map((entry) {
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
              ),
              actions: [
                if (subject.gradePoint != null)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, -1.0),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Bỏ điểm'),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gradedCount = _subjects.where((s) => s.gradePoint != null).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.gpaProjectionTitle),
        actions: [
          IconButton(
            tooltip: 'Hướng dẫn cách tính',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: BlocBuilder<GpaBloc, GpaState>(
        builder: (context, state) {
          final result = state.result;
          final hasInputError = _currentGpaError != null ||
              _completedCreditsError != null ||
              _remainingCreditsError != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 0. Thanh giới thiệu nhanh giúp người mới hiểu trong 3 giây
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nhập GPA & tín chỉ hiện tại, chọn mục tiêu bên dưới để biết các môn sắp tới cần đạt điểm bao nhiêu.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 1. Thẻ kết quả dự phóng nổi bật
                _buildResultCard(
                  context,
                  result,
                  state,
                  hasInputError: hasInputError,
                ),

                const SizedBox(height: 14),

                // 2. Bước 1: Nhập tình hình hiện tại
                _buildCurrentSituationCard(
                  context,
                  state,
                  gradedCount: gradedCount,
                ),

                const SizedBox(height: 14),

                // 3. Bước 2: Chọn GPA mục tiêu
                _buildTargetCard(context, state),

                const SizedBox(height: 14),

                // 4. Bước 3: Bảng điểm từng môn (tự tính + thang điểm chữ)
                _buildSubjectsCard(context, gradedCount: gradedCount),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentSituationCard(
    BuildContext context,
    GpaState state, {
    required int gradedCount,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalCredits = state.completedCredits + state.remainingCredits;

    return Card(
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
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                  child: Text(
                    '1',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tình hình học tập hiện tại',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (gradedCount > 0)
                  FilledButton.tonalIcon(
                    onPressed: _calculateFromRealSubjects,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 15),
                    label: Text(
                      'Lấy từ $gradedCount môn',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('gpa_current_input'),
              controller: _currentGpaController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'GPA đã có (hệ 4.0)',
                hintText: 'VD: 3.00',
                helperText: 'Điểm TB tích lũy từ 0.0 đến 4.0',
                errorText: _currentGpaError,
                prefixIcon: const Icon(Icons.grade_rounded),
                suffixText: '/ 4.0',
                filled: true,
                fillColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onCurrentGpaChanged,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final completedField = TextField(
                  key: const ValueKey('gpa_completed_credits_input'),
                  controller: _completedCreditsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'TC đã tích lũy',
                    hintText: '60',
                    helperText: 'Đã có điểm',
                    suffixText: 'TC',
                    errorText: _completedCreditsError,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _onCompletedCreditsChanged,
                );

                final remainingField = TextField(
                  key: const ValueKey('gpa_remaining_credits_input'),
                  controller: _remainingCreditsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'TC sắp học',
                    hintText: '30',
                    helperText: 'Còn lại / kỳ tới',
                    suffixText: 'TC',
                    errorText: _remainingCreditsError,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _onRemainingCreditsChanged,
                );

                if (constraints.maxWidth < 310) {
                  return Column(
                    children: [
                      completedField,
                      const SizedBox(height: 12),
                      remainingField,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: completedField),
                    const SizedBox(width: 12),
                    Expanded(child: remainingField),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calculate_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tổng cộng: $totalCredits tín chỉ (${state.completedCredits} đã học + ${state.remainingCredits} sắp học)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetCard(BuildContext context, GpaState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presets = <({double gpa, String label})>[
      (gpa: 2.5, label: '2.5 (Khá)'),
      (gpa: 3.2, label: '3.2 (Giỏi)'),
      (gpa: 3.6, label: '3.6 (Xuất sắc)'),
    ];

    return Card(
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
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.amber.withValues(alpha: 0.2),
                        child: const Text(
                          '2',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          AppStrings.targetGpa,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.targetGpa.toStringAsFixed(2)} (${_rankLabel(state.targetGpa)})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: presets.map((p) {
                final selected = (state.targetGpa - p.gpa).abs() < 0.01;
                return ChoiceChip(
                  label: Text(p.label, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    context.read<GpaBloc>().add(GpaTargetChanged(p.gpa));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Slider(
              value: state.targetGpa.clamp(0.0, 4.0),
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
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '0.0',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '2.5 Khá',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '3.2 Giỏi',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '4.0 Xuất sắc',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsCard(
    BuildContext context, {
    required int gradedCount,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalSubjectCredits =
        _subjects.fold<int>(0, (sum, s) => sum + s.credits);

    return Card(
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
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.teal.withValues(alpha: 0.16),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bảng điểm từng môn',
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
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Chạm vào môn bên dưới để nhập điểm chữ (A+, A, B+...). Hệ thống sẽ tự cộng lại GPA & tín chỉ ở Bước 1 ($gradedCount/${_subjects.length} môn đã có điểm • $totalSubjectCredits TC).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              childrenPadding:
                  const EdgeInsets.fromLTRB(8, 0, 8, 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              collapsedBackgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              leading: Icon(
                Icons.rule_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              title: const Text(
                'Xem bảng quy đổi điểm chữ (A+ → F)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: const [
                    _ScaleBadge('A+ = 4.0', 'Xuất sắc'),
                    _ScaleBadge('A = 3.7', 'Giỏi'),
                    _ScaleBadge('B+ = 3.5', 'Khá giỏi'),
                    _ScaleBadge('B = 3.0', 'Khá'),
                    _ScaleBadge('C+ = 2.5', 'TB khá'),
                    _ScaleBadge('C = 2.0', 'Trung bình'),
                    _ScaleBadge('D+ = 1.5', 'TB yếu'),
                    _ScaleBadge('D = 1.0', 'Yếu'),
                    _ScaleBadge('F = 0.0', 'Học lại'),
                  ],
                ),
              ],
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
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _subjects.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final sub = _subjects[index];
                  final gp = sub.gradePoint;
                  final hasGrade = gp != null;
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: Text(
                      'Mã: ${sub.code} • ${sub.credits} tín chỉ',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasGrade
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasGrade
                            ? '${gp.toStringAsFixed(2)} (${sub.letterGrade ?? ''})'
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
              if (gradedCount > 0) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _calculateFromRealSubjects,
                    icon: const Icon(Icons.sync_alt_rounded, size: 18),
                    label: const Text('Áp dụng điểm các môn lên Bước 1'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    GpaProjectionResult? result,
    GpaState state, {
    required bool hasInputError,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (result == null) return const SizedBox.shrink();

    if (hasInputError) {
      return Card(
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note_rounded,
                      size: 26, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'CẦN KIỂM TRA LẠI SỐ LIỆU',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Vui lòng điền đủ GPA (0.0 - 4.0) và số tín chỉ hợp lệ ở Bước 1 để xem kết quả.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Color cardBg;
    Color textColor;
    IconData icon;
    String statusTitle;
    String detailMessage;

    final totalCredits = state.completedCredits + state.remainingCredits;
    double? maxPossibleGpa;
    double? suggestedReachableTarget;

    switch (result.status) {
      case GpaProjectionStatus.achievable:
        cardBg = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        icon = Icons.trending_up_rounded;
        statusTitle = 'MỤC TIÊU KHẢ THI';
        if (state.completedCredits == 0) {
          detailMessage =
              'Bạn chưa có tín chỉ tích lũy. Để đạt ${state.targetGpa.toStringAsFixed(2)}, ${state.remainingCredits} tín chỉ sắp tới cần đạt TB tối thiểu ${result.requiredGpa.toStringAsFixed(2)} / 4.0.';
        } else {
          detailMessage =
              'Bạn đang có ${state.currentGpa.toStringAsFixed(2)} (${state.completedCredits} TC). Để tổng $totalCredits TC đạt ${state.targetGpa.toStringAsFixed(2)}, ${state.remainingCredits} TC còn lại cần đạt TB tối thiểu ${result.requiredGpa.toStringAsFixed(2)} / 4.0.';
        }
      case GpaProjectionStatus.alreadyAchieved:
        cardBg = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = Icons.emoji_events_rounded;
        statusTitle = 'ĐÃ ĐẠT MỤC TIÊU!';
        detailMessage = state.remainingCredits == 0
            ? 'Với ${state.completedCredits} tín chỉ, GPA hiện tại ${state.currentGpa.toStringAsFixed(2)} đã đạt mục tiêu ${state.targetGpa.toStringAsFixed(2)}!'
            : 'GPA hiện tại ${state.currentGpa.toStringAsFixed(2)} (${state.completedCredits} TC) đã vượt mức cần thiết cho mục tiêu ${state.targetGpa.toStringAsFixed(2)}. Chỉ cần giữ vững điểm không để tụt nhiều!';
      case GpaProjectionStatus.impossible:
        cardBg = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        icon = Icons.warning_amber_rounded;
        statusTitle = 'MỤC TIÊU CHƯA KHẢ THI';
        if (state.remainingCredits == 0) {
          detailMessage =
              'Bạn còn 0 tín chỉ sắp học nên GPA giữ nguyên ở ${state.currentGpa.toStringAsFixed(2)}, chưa thể đạt ${state.targetGpa.toStringAsFixed(2)}.';
        } else {
          maxPossibleGpa =
              ((state.currentGpa * state.completedCredits) +
                      (4.0 * state.remainingCredits)) /
                  totalCredits;
          suggestedReachableTarget = (maxPossibleGpa * 20).floor() / 20.0;
          detailMessage =
              'Cần đạt ${result.requiredGpa.toStringAsFixed(2)} / 4.0 (vượt giới hạn tối đa 4.0). Kể cả đạt toàn A+ (4.0) trong ${state.remainingCredits} TC tới, GPA cao nhất bạn đạt được là ${maxPossibleGpa.toStringAsFixed(2)} / 4.0.';
        }
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
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: textColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    statusTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            if (result.status == GpaProjectionStatus.achievable) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      'Cần đạt TB tối thiểu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${result.requiredGpa.toStringAsFixed(2)} / 4.0',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '≈ ${_equivalentLetterHint(result.requiredGpa)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              detailMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: textColor,
                height: 1.4,
              ),
            ),
            if (suggestedReachableTarget != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () {
                  final safeTarget = suggestedReachableTarget ?? 0.0;
                  context.read<GpaBloc>().add(
                        GpaTargetChanged(safeTarget.clamp(0.0, 4.0)),
                      );
                },
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: Text(
                  'Hạ mục tiêu về mức khả thi (${suggestedReachableTarget.toStringAsFixed(2)})',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScaleBadge extends StatelessWidget {
  final String grade;
  final String meaning;

  const _ScaleBadge(this.grade, this.meaning);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        '$grade • $meaning',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
