import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';

/// Màn hình Cài đặt & Quản lý Thông báo Nhắc giờ học (Chủ đề 7).
class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<NotificationBloc>()..add(const InitNotificationEvent()),
      child: const _NotificationSettingsView(),
    );
  }
}

class _NotificationSettingsView extends StatelessWidget {
  const _NotificationSettingsView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notificationSettingsTitle),
      ),
      body: BlocConsumer<NotificationBloc, NotificationState>(
        listener: (context, state) {
          if (state is NotificationLoaded && state.feedbackMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.feedbackMessage!),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is NotificationLoading || state is NotificationInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is NotificationError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.read<NotificationBloc>().add(const InitNotificationEvent()),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final loaded = state as NotificationLoaded;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 1. Thẻ trạng thái quyền hệ thống
              Card(
                elevation: 0,
                color: loaded.isNotificationGranted
                    ? Colors.green.shade50
                    : Colors.amber.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: loaded.isNotificationGranted
                        ? Colors.green.shade200
                        : Colors.amber.shade300,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            loaded.isNotificationGranted
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                            color: loaded.isNotificationGranted
                                ? Colors.green.shade700
                                : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loaded.isNotificationGranted
                                  ? AppStrings.notificationPermissionGranted
                                  : AppStrings.notificationPermissionDenied,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: loaded.isNotificationGranted
                                    ? Colors.green.shade900
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loaded.isNotificationGranted
                            ? 'Ứng dụng đã sẵn sàng gửi thông báo nhắc trước khi vào ca học.'
                            : 'Vui lòng cấp quyền để nhận cảnh báo ca học sắp diễn ra.',
                        style: TextStyle(
                          fontSize: 13,
                          color: loaded.isNotificationGranted
                              ? Colors.green.shade900
                              : Colors.amber.shade900,
                        ),
                      ),
                      if (!loaded.isNotificationGranted) ...[
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.security_rounded),
                          label: const Text('Cấp quyền ngay'),
                          onPressed: () {
                            context.read<NotificationBloc>().add(const RequestNotificationPermissionEvent());
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Chọn thời gian nhắc trước giờ học
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.leadTimeTitle,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hệ thống sẽ nhắc bạn trước khi bắt đầu ca học:',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 5, label: Text('5p')),
                          ButtonSegment(value: 10, label: Text('10p')),
                          ButtonSegment(value: 15, label: Text('15p (chuẩn)')),
                          ButtonSegment(value: 30, label: Text('30p')),
                        ],
                        selected: {loaded.leadMinutes},
                        onSelectionChanged: (selection) {
                          context.read<NotificationBloc>().add(ChangeLeadMinutesEvent(selection.first));
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Thẻ thống kê lịch nhắc đang chờ
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      '${loaded.pendingCount}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: const Text(AppStrings.pendingReminders),
                  subtitle: Text(
                    loaded.pendingCount > 0
                        ? 'Đang có ${loaded.pendingCount} ca học được lên lịch chính xác.'
                        : AppStrings.noPendingReminders,
                  ),
                  trailing: loaded.pendingCount > 0
                      ? IconButton(
                          tooltip: AppStrings.cancelAllReminders,
                          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                          onPressed: () {
                            context.read<NotificationBloc>().add(const CancelAllRemindersEvent());
                          },
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 24),

              // 4. Các nút thao tác
              FilledButton.icon(
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text(AppStrings.scheduleRollingReminders),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  context.read<NotificationBloc>().add(const ScheduleRollingRemindersEvent());
                },
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text(AppStrings.testNotificationTitle),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  context.read<NotificationBloc>().add(const TriggerTestNotificationEvent());
                },
              ),

              const SizedBox(height: 24),

              // 5. Ghi chú kiến thức bảo vệ đồ án
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Cơ chế hoạt động CĐ 7 (Chống rớt thông báo):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Sử dụng Exact Alarm (exactAllowWhileIdle) để đánh thức máy ở chế độ tiết kiệm pin (Doze mode).\n'
                      '• Áp dụng thuật toán cuốn chiếu 7 ngày tới, khống chế ≤ 60 thông báo để không tràn quota OS.\n'
                      '• Tích hợp Receiver BOOT_COMPLETED giúp tự động phục hồi lịch nhắc sau khi khởi động lại máy.',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
