import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/security/bloc/auth_lock_bloc.dart';
import '../../../../core/security/bloc/auth_lock_event.dart';
import '../../../../core/security/bloc/auth_lock_state.dart';

/// Màn hình khóa ứng dụng S01 (LockPage) theo đặc tả CĐ 11 (mục 4.3, 6.2).
/// Hỗ trợ xác thực vân tay, FaceID hoặc mã PIN thiết bị.
class AppLockPage extends StatelessWidget {
  final AuthLockBloc? bloc;
  const AppLockPage({super.key, this.bloc});

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider.value(
        value: bloc!,
        child: const _AppLockView(),
      );
    }

    try {
      final existing = context.read<AuthLockBloc>();
      return BlocProvider.value(
        value: existing,
        child: const _AppLockView(),
      );
    } catch (_) {
      return BlocProvider.value(
        value: getIt<AuthLockBloc>(),
        child: const _AppLockView(),
      );
    }
  }
}

class _AppLockView extends StatefulWidget {
  const _AppLockView();

  @override
  State<_AppLockView> createState() => _AppLockViewState();
}

class _AppLockViewState extends State<_AppLockView> {
  @override
  void initState() {
    super.initState();
    // Check biometrics availability on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthLockBloc>().add(const CheckAuthStatus());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: BlocListener<AuthLockBloc, AuthLockState>(
          listener: (context, state) {
            if (state is AuthUnlocked) {
              final router = GoRouter.maybeOf(context);
              if (router != null) {
                if (router.canPop()) {
                  router.pop();
                } else {
                  router.go(Routes.timetable);
                }
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            }
          },
          child: BlocBuilder<AuthLockBloc, AuthLockState>(
          builder: (context, state) {
            final isAuthenticating =
                state is AuthLocked && state.isAuthenticating;
            final errorMessage =
                state is AuthLocked ? state.errorMessage : null;
            final isNotAvailable = state is BiometricsNotAvailable;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Security Shield / App Logo
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // App Title & Tagline
                    Text(
                      AppStrings.appName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.appLockSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Error message banner
                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.colorScheme.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                errorMessage,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Biometrics not available warning
                    if (isNotAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          AppStrings.biometricsNotAvailable,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),

                    // Main Unlock Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: isAuthenticating
                            ? null
                            : () {
                                if (isNotAvailable) {
                                  // Fallback bypass when device lacks biometrics/PIN
                                  context
                                      .read<AuthLockBloc>()
                                      .add(const UnlockApp());
                                } else {
                                  context.read<AuthLockBloc>().add(
                                        const AuthenticateWithBiometrics(),
                                      );
                                }
                              },
                        icon: isAuthenticating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isNotAvailable
                                    ? Icons.arrow_forward_rounded
                                    : Icons.fingerprint_rounded,
                                size: 24,
                              ),
                        label: Text(
                          isNotAvailable
                              ? AppStrings.ok
                              : AppStrings.unlockWithBiometrics,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
}
