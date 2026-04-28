import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/student_route_history_state.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../model/classroom_models.dart';
import '../../service/classroom_service.dart';
import '../../state/student_class_scope_state.dart';
import '../../../auth/state/auth_provider.dart';

enum StudentSection { exams, results }

class StudentLayout extends ConsumerWidget {
  const StudentLayout({
    required this.title,
    required this.activeSection,
    required this.child,
    super.key,
    this.subtitle,
    this.actions = const <Widget>[],
    this.contentPadding = const EdgeInsets.all(AppSpacing.md),
  });

  final String title;
  final String? subtitle;
  final StudentSection activeSection;
  final Widget child;
  final List<Widget> actions;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 980;
    final currentRoutePath = GoRouterState.of(context).matchedLocation;

    final user = ref.watch(authProvider.select((state) => state.user));
    final displayName = user?.effectiveDisplayName ?? 'Siswa';
    final username = user?.username ?? 'siswa';
    final fallbackClassName = user?.className?.trim().isNotEmpty == true
        ? user!.className!.trim()
        : 'Kelas belum ditetapkan';
    final myClassOptionsAsync = ref.watch(myClassOptionsProvider);
    final selectedClassId = ref.watch(effectiveStudentClassIdProvider);
    final classOptions = myClassOptionsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <StudentClassOption>[],
    );
    String? selectedClassName;
    for (final item in classOptions) {
      if (item.id != selectedClassId) {
        continue;
      }
      final trimmedName = item.name.trim();
      if (trimmedName.isEmpty) {
        continue;
      }
      selectedClassName = trimmedName;
      break;
    }
    final className = selectedClassName ?? fallbackClassName;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(studentRouteHistoryProvider.notifier)
          .recordVisit(currentRoutePath);
    });

    Future<void> logout() async {
      final confirmed = await _showLogoutConfirmationDialog(context);
      if (!context.mounted || !confirmed) {
        return;
      }
      await ref.read(authProvider.notifier).logout();
    }

    Future<void> selectClass(String? classId) async {
      await ref
          .read(studentSelectedClassIdProvider.notifier)
          .setSelectedClassId(classId);
      if (context.mounted && currentRoutePath != '/exam') {
        context.go('/exam');
      }
    }

    Future<void> handleBackPressed() async {
      final previousRoute = await ref
          .read(studentRouteHistoryProvider.notifier)
          .popPreviousRoute(currentRoute: currentRoutePath);

      if (previousRoute != null &&
          previousRoute.trim().isNotEmpty &&
          previousRoute != currentRoutePath) {
        if (!context.mounted) {
          return;
        }
        context.go(previousRoute);
        return;
      }

      if (!context.mounted) {
        return;
      }
      final shouldExit = await _showExitAppConfirmationDialog(context);
      if (!context.mounted || !shouldExit) {
        return;
      }
      await SystemNavigator.pop();
    }

    void navigateTo(String path) {
      if (GoRouterState.of(context).matchedLocation != path) {
        context.go(path);
      }
      if (!isDesktop && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    final scaffold = !isDesktop
        ? Scaffold(
            backgroundColor: AppColors.bgBase,
            appBar: AppBar(
              title: Text(title),
              actions: actions,
            ),
            drawer: Drawer(
              child: SafeArea(
                child: _StudentSidebar(
                  activeSection: activeSection,
                  displayName: displayName,
                  username: username,
                  className: className,
                  classOptions: classOptions,
                  selectedClassId: selectedClassId,
                  classOptionsLoading: myClassOptionsAsync.isLoading,
                  classOptionsError: myClassOptionsAsync.hasError
                      ? myClassOptionsAsync.error.toString()
                      : null,
                  onSelectClass: selectClass,
                  onNavigate: navigateTo,
                  onLogout: logout,
                ),
              ),
            ),
            body: Padding(
              padding: contentPadding,
              child: child,
            ),
          )
        : Scaffold(
            backgroundColor: AppColors.bgBase,
            body: SafeArea(
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 286,
                    child: _StudentSidebar(
                      activeSection: activeSection,
                      displayName: displayName,
                      username: username,
                      className: className,
                      classOptions: classOptions,
                      selectedClassId: selectedClassId,
                      classOptionsLoading: myClassOptionsAsync.isLoading,
                      classOptionsError: myClassOptionsAsync.hasError
                          ? myClassOptionsAsync.error.toString()
                          : null,
                      onSelectClass: selectClass,
                      onNavigate: navigateTo,
                      onLogout: logout,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        _DesktopHeader(
                          title: title,
                          subtitle: subtitle,
                          actions: actions,
                        ),
                        Expanded(
                          child: Padding(
                            padding: contentPadding,
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await handleBackPressed();
      },
      child: scaffold,
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.title,
    required this.actions,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null &&
                    subtitle!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Text(
              _formatDate(now),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ...actions,
        ],
      ),
    );
  }
}

class _StudentSidebar extends StatelessWidget {
  const _StudentSidebar({
    required this.activeSection,
    required this.displayName,
    required this.username,
    required this.className,
    required this.classOptions,
    required this.selectedClassId,
    required this.classOptionsLoading,
    required this.classOptionsError,
    required this.onSelectClass,
    required this.onNavigate,
    required this.onLogout,
  });

  final StudentSection activeSection;
  final String displayName;
  final String username;
  final String className;
  final List<StudentClassOption> classOptions;
  final String? selectedClassId;
  final bool classOptionsLoading;
  final String? classOptionsError;
  final ValueChanged<String?> onSelectClass;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menu = <_StudentMenuItem>[
      const _StudentMenuItem(
        section: StudentSection.exams,
        title: 'Daftar Ujian',
        icon: Icons.menu_book_rounded,
        path: '/exam',
      ),
      const _StudentMenuItem(
        section: StudentSection.results,
        title: 'Hasil Ujian',
        icon: Icons.analytics_rounded,
        path: '/result',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            theme.colorScheme.surface,
            const Color(0xFFE4F1E7),
          ],
        ),
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF128B4D).withValues(alpha: 0.1),
                border: Border.all(
                  color: const Color(0xFF128B4D).withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF128B4D),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Panel Siswa',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lihat ujian aktif dan riwayat nilaimu.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              itemCount: menu.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final item = menu[index];
                final selected = item.section == activeSection;
                return ListTile(
                  onTap: () => onNavigate(item.path),
                  selected: selected,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selectedTileColor:
                      const Color(0xFF128B4D).withValues(alpha: 0.13),
                  leading: Icon(
                    item.icon,
                    color: selected
                        ? const Color(0xFF128B4D)
                        : AppColors.textSecondary,
                  ),
                  title: Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? const Color(0xFF128B4D)
                          : AppColors.textPrimary,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Masuk sebagai',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      className,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (classOptionsLoading)
                      Text(
                        'Memuat daftar kelas...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    else if (classOptionsError != null &&
                        classOptionsError!.trim().isNotEmpty)
                      Text(
                        'Daftar kelas belum bisa dimuat.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      )
                    else if (classOptions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: classOptions.any(
                          (item) => item.id == selectedClassId,
                        )
                            ? selectedClassId
                            : classOptions.first.id,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Kelas Akses',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: classOptions
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: onSelectClass,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Keluar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentMenuItem {
  const _StudentMenuItem({
    required this.section,
    required this.title,
    required this.icon,
    required this.path,
  });

  final StudentSection section;
  final String title;
  final IconData icon;
  final String path;
}

String _formatDate(DateTime date) {
  const days = <String>[
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  const months = <String>[
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  final day = days[date.weekday - 1];
  final month = months[date.month - 1];
  return '$day, ${date.day} $month ${date.year}';
}

Future<bool> _showLogoutConfirmationDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah kamu yakin ingin keluar dari akun siswa?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Keluar'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

Future<bool> _showExitAppConfirmationDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Keluar Aplikasi'),
        content: const Text('Apakah anda ingin keluar aplikasi?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
