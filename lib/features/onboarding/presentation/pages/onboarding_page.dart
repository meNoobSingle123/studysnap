import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/security/app_onboarding_listenable.dart';
import '../../../../core/security/key_storage_service.dart';

class OnboardingPage extends StatefulWidget {
  final KeyStorageService? keyStorageService;

  const OnboardingPage({super.key, this.keyStorageService});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  KeyStorageService get _keyStorage {
    return widget.keyStorageService ??
        (getIt.isRegistered<KeyStorageService>()
            ? getIt<KeyStorageService>()
            : KeyStorageService());
  }

  Future<void> _completeOnboarding() async {
    await _keyStorage.setOnboardingCompleted(true);
    AppOnboardingListenable.instance.setCompleted(true);
    if (mounted) {
      try {
        context.go(Routes.timetable);
      } catch (_) {
        Navigator.of(context).maybePop();
      }
    }
  }

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      badge: 'THỜI KHÓA BIỂU & NHẮC HỌC',
      title: 'Quản lý Ca học & Báo thức thông minh',
      description:
          'Theo dõi lịch học theo tuần và tháng, nhận thông báo ca học chuẩn xác và mở nhanh bài học ngay trên Thẻ học nhanh một chạm.',
      icon: Icons.calendar_month_rounded,
      highlightColor: Color(0xFF5E48E8),
      pills: ['Lịch tuần trực quan', 'Báo thức chuẩn xác', 'Thẻ học nhanh'],
    ),
    _OnboardingItem(
      badge: 'GHI CHÉP ĐA PHƯƠNG TIỆN',
      title: 'Ghi chú bài giảng & Nét vẽ Vector',
      description:
          'Viết vẽ trên Canvas vector mượt mà, quét nhận diện chữ bảng viết bằng AI OCR không cần mạng, và xem video bài giảng với Split-View tiện lợi.',
      icon: Icons.draw_rounded,
      highlightColor: Color(0xFF00897B),
      pills: ['Canvas vector mượt', 'OCR quét bảng offline', 'Video Split-View'],
    ),
    _OnboardingItem(
      badge: 'TRÍ TUỆ NHÂN TẠO & XUẤT BẢN',
      title: 'Trợ lý Học tập AI & Xuất PDF A4',
      description:
          'Tự động tóm tắt bài giảng súc tích, tạo câu hỏi trắc nghiệm ôn thi tức thì (Active Recall) và xuất tài liệu ghi chú PDF A4 chuẩn tiếng Việt.',
      icon: Icons.auto_awesome_rounded,
      highlightColor: Color(0xFFE65100),
      pills: ['Tóm tắt thông minh', 'Trắc nghiệm ôn thi', 'Xuất PDF A4 chuẩn'],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLastPage = _currentPage == _items.length - 1;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _completeOnboarding,
            child: Text(
              'Bỏ qua',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Biểu tượng minh họa
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: item.highlightColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: item.highlightColor.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              item.icon,
                              size: 54,
                              color: item.highlightColor,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Huy hiệu phân loại
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: item.highlightColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.badge,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: item.highlightColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Tiêu đề
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Mô tả chi tiết
                          Text(
                            item.description,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Các tính năng nổi bật (Pills)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: item.pills.map((pill) {
                              return Chip(
                                label: Text(pill),
                                labelStyle: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                                backgroundColor: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Footer: Indicator & Action Button ─────────────────────────
            Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                children: [
                  // Dấu chấm phân trang (Indicators)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_items.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Nút chuyển trang hoặc Hoàn tất
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        if (isLastPage) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Text(
                        isLastPage ? 'Bắt đầu sử dụng StudySnap' : 'Tiếp theo',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
}

class _OnboardingItem {
  final String badge;
  final String title;
  final String description;
  final IconData icon;
  final Color highlightColor;
  final List<String> pills;

  const _OnboardingItem({
    required this.badge,
    required this.title,
    required this.description,
    required this.icon,
    required this.highlightColor,
    required this.pills,
  });
}
