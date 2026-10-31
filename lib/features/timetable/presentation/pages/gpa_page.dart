import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
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
                            const SizedBox(width: 10),
                            Text(
                              'Thông tin học tập hiện tại',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
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
                            final d = double.tryParse(val);
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
                                  labelText: AppStrings.completedCredits,
                                  hintText: '60',
                                  prefixIcon: const Icon(Icons.check_circle_outline),
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
                                  final i = int.tryParse(val);
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
                                  labelText: AppStrings.remainingCredits,
                                  hintText: '30',
                                  prefixIcon: const Icon(Icons.timelapse_outlined),
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
                                  final i = int.tryParse(val);
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

    switch (result.status) {
      case GpaProjectionStatus.achievable:
        cardBg = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        icon = Icons.trending_up_rounded;
        statusTitle = 'MỤC TIÊU KHẢ THI';
      case GpaProjectionStatus.alreadyAchieved:
        cardBg = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = Icons.emoji_events_rounded;
        statusTitle = 'ĐÃ ĐẠT MỤC TIÊU!';
      case GpaProjectionStatus.impossible:
        cardBg = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        icon = Icons.warning_amber_rounded;
        statusTitle = 'MỤC TIÊU KHÔNG KHẢ THI';
      case GpaProjectionStatus.invalidInput:
        cardBg = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        icon = Icons.info_outline_rounded;
        statusTitle = 'THÔNG TIN CHƯA HỢP LỆ';
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
              result.message,
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
                      AppStrings.gpaResult,
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
