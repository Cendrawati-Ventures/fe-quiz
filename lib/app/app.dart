import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/state/auth_provider.dart';
import 'router.dart';
import 'theme/colors.dart';
import 'theme/typography.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _AppView());
  }
}

class _AppView extends ConsumerWidget {
  const _AppView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final isAdmin = ref.watch(authProvider.select((value) => value.isAdmin));
    final seed = isAdmin ? AppColors.adminPrimary : AppColors.studentPrimary;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: AppColors.bgSurface,
    ).copyWith(
      primary: seed,
      onPrimary: Colors.white,
      secondary: AppColors.accentSky,
      tertiary: AppColors.accentSun,
      surface: AppColors.bgSurface,
      surfaceContainerHighest: AppColors.bgSurfaceSoft,
      outlineVariant: AppColors.borderDefault,
      error: AppColors.danger,
    );

    return MaterialApp.router(
      title: 'Online Exam System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.bgBase,
        textTheme: AppTypography.textTheme,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: AppColors.bgBase,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: AppTypography.textTheme.titleLarge,
        ),
        cardTheme: CardThemeData(
          color: AppColors.bgSurface,
          elevation: 0,
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderDefault),
          ),
        ),
        dividerColor: AppColors.borderDefault,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bgSurface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderDefault),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderDefault),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
          ),
          labelStyle: AppTypography.textTheme.bodyMedium,
          hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.bgSurfaceSoft,
          selectedColor: colorScheme.primaryContainer,
          side: const BorderSide(color: AppColors.borderDefault),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          labelStyle:
              AppTypography.textTheme.labelLarge?.copyWith(fontSize: 13),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colorScheme.primary,
          contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onPrimary,
          ),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: colorScheme.primary,
          linearTrackColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: AppTypography.textTheme.labelLarge?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
