import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../auth/state/auth_provider.dart';

enum AdminSection {
  dashboard,
  classes,
  exams,
  subjects,
  questions,
  students,
  results
}

class AdminLayout extends ConsumerWidget {
  const AdminLayout({
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
  final AdminSection activeSection;
  final Widget child;
  final List<Widget> actions;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 980;
    final user = ref.watch(authProvider.select((state) => state.user));
    final displayName = user?.effectiveDisplayName ?? 'Admin';
    final username = user?.username ?? 'admin';
    final isUpdatingDisplayName = ref.watch(authProvider.select((state) =>
        state.status == AuthStatus.authenticated && state.isLoading));

    void logout() async {
      final confirmed = await _showLogoutConfirmationDialog(
        context,
        roleLabel: 'admin',
      );
      if (!context.mounted || !confirmed) {
        return;
      }
      ref.read(authProvider.notifier).logout();
    }

    void navigateTo(String path) {
      if (GoRouterState.of(context).matchedLocation != path) {
        context.go(path);
      }
      if (!isDesktop && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    void editDisplayName() async {
      final initial = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : username;
      final nextDisplayName = await _showEditDisplayNameDialog(
        context,
        initialValue: initial,
      );
      if (nextDisplayName == null || nextDisplayName.trim().isEmpty) {
        return;
      }

      final error = await ref
          .read(authProvider.notifier)
          .updateDisplayName(nextDisplayName);
      if (!context.mounted) {
        return;
      }

      final message = error ?? 'Nama admin berhasil diperbarui.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: actions,
        ),
        drawer: Drawer(
          child: SafeArea(
            child: _AdminSidebar(
              activeSection: activeSection,
              displayName: displayName,
              username: username,
              isUpdatingDisplayName: isUpdatingDisplayName,
              onEditDisplayName: editDisplayName,
              onNavigate: navigateTo,
              onLogout: logout,
            ),
          ),
        ),
        body: Padding(
          padding: contentPadding,
          child: child,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 286,
              child: _AdminSidebar(
                activeSection: activeSection,
                displayName: displayName,
                username: username,
                isUpdatingDisplayName: isUpdatingDisplayName,
                onEditDisplayName: editDisplayName,
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
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
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

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.activeSection,
    required this.displayName,
    required this.username,
    required this.isUpdatingDisplayName,
    required this.onEditDisplayName,
    required this.onNavigate,
    required this.onLogout,
  });

  final AdminSection activeSection;
  final String displayName;
  final String username;
  final bool isUpdatingDisplayName;
  final VoidCallback onEditDisplayName;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menu = <_AdminMenuItem>[
      const _AdminMenuItem(
        section: AdminSection.dashboard,
        title: 'Beranda',
        icon: Icons.dashboard_rounded,
        path: '/admin/dashboard',
      ),
      const _AdminMenuItem(
        section: AdminSection.classes,
        title: 'Kelas',
        icon: Icons.apartment_rounded,
        path: '/admin/classes',
      ),
      const _AdminMenuItem(
        section: AdminSection.subjects,
        title: 'Ujian',
        icon: Icons.menu_book_rounded,
        path: '/admin/subjects',
      ),
      const _AdminMenuItem(
        section: AdminSection.questions,
        title: 'Bank Soal',
        icon: Icons.quiz_rounded,
        path: '/admin/questions',
      ),
      const _AdminMenuItem(
        section: AdminSection.students,
        title: 'Akun Siswa',
        icon: Icons.group_rounded,
        path: '/admin/students',
      ),
      const _AdminMenuItem(
        section: AdminSection.results,
        title: 'Hasil Ujian',
        icon: Icons.analytics_rounded,
        path: '/admin/results',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            theme.colorScheme.surface,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.16),
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
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary,
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Panel Admin Guru',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kelola ujian lebih rapi dan cepat.',
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
                      theme.colorScheme.primary.withValues(alpha: 0.13),
                  leading: Icon(
                    item.icon,
                    color: selected
                        ? theme.colorScheme.primary
                        : AppColors.textSecondary,
                  ),
                  title: Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.primary
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
                    if (displayName.trim().toLowerCase() !=
                        username.trim().toLowerCase()) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            isUpdatingDisplayName ? null : onEditDisplayName,
                        icon: isUpdatingDisplayName
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.edit_rounded, size: 18),
                        label: Text(
                          isUpdatingDisplayName ? 'Menyimpan...' : 'Ubah Nama',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
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

class _AdminMenuItem {
  const _AdminMenuItem({
    required this.section,
    required this.title,
    required this.icon,
    required this.path,
  });

  final AdminSection section;
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

Future<String?> _showEditDisplayNameDialog(
  BuildContext context, {
  required String initialValue,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => _EditDisplayNameDialog(initialValue: initialValue),
  );
}

class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah Nama Admin'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Nama Tampilan',
            hintText: 'Contoh: Bu Rini',
          ),
          maxLength: 120,
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) {
              return 'Nama tampilan wajib diisi';
            }
            if (trimmed.length > 120) {
              return 'Nama tampilan maksimal 120 karakter';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

Future<bool> _showLogoutConfirmationDialog(
  BuildContext context, {
  required String roleLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: Text('Apakah Anda yakin ingin keluar dari akun $roleLabel?'),
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
