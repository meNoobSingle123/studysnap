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

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.gpaProjectionTitle),
      ),
      body: BlocBuilder<GpaBloc, GpaState>(
        builder: (context, state) {
          final result = state.result;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Thẻ kết quả hiển thị nổi bật ở trên cùng
                _buildResultCard(context, result),

                const SizedBox(height: 24),

                // 2. Nhóm trường nhập dữ liệu số
                Text(
                  'Thông tin học tập hiện tại',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // GPA hiện tại
                TextField(
                  controller: _currentGpaController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: AppStrings.currentGpa,
                    hintText: 'VD: 3.2',
                    prefixIcon: Icon(Icons.school_outlined),
                    suffixText: '/ 4.0',
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
                        decoration: const InputDecoration(
                          labelText: AppStrings.completedCredits,
                          hintText: '60',
                          prefixIcon: Icon(Icons.check_circle_outline),
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
                        decoration: const InputDecoration(
                          labelText: AppStrings.remainingCredits,
                          hintText: '30',
                          prefixIcon: Icon(Icons.timelapse_outlined),
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

                const SizedBox(height: 24),

                // 3. Thanh trượt chọn GPA mục tiêu (Chủ đề 2)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppStrings.targetGpa,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                state.targetGpa.toStringAsFixed(2),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
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
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('0.0 (Yếu)', style: TextStyle(fontSize: 12)),
                            Text('2.5 (Khá)', style: TextStyle(fontSize: 12)),
                            Text('3.2 (Giỏi)', style: TextStyle(fontSize: 12)),
                            Text('4.0 (Xuất sắc)',
                                style: TextStyle(fontSize: 12)),
                          ],
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

  Widget _buildResultCard(BuildContext context, GpaProjectionResult? result) {
    final theme = Theme.of(context);
    if (result == null) return const SizedBox.shrink();

    Color cardBg;
    Color textColor;
    IconData icon;

    switch (result.status) {
      case GpaProjectionStatus.achievable:
        cardBg = theme.colorScheme.primaryContainer;
        textColor = theme.colorScheme.onPrimaryContainer;
        icon = Icons.trending_up_rounded;
      case GpaProjectionStatus.alreadyAchieved:
        cardBg = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = Icons.emoji_events_outlined;
      case GpaProjectionStatus.impossible:
        cardBg = theme.colorScheme.errorContainer;
        textColor = theme.colorScheme.onErrorContainer;
        icon = Icons.warning_amber_rounded;
      case GpaProjectionStatus.invalidInput:
        cardBg = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurfaceVariant;
        icon = Icons.info_outline;
    }

    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(icon, size: 48, color: textColor),
            const SizedBox(height: 12),
            Text(
              AppStrings.gpaResult,
              style: theme.textTheme.labelLarge?.copyWith(
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
