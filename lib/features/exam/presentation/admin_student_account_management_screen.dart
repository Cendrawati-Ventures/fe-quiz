import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../app/theme/spacing.dart";
import "../../../core/network/api_error.dart";
import "../../../shared/components/app_button.dart";
import "../../../shared/components/app_card.dart";
import "../service/student_account_service.dart";

class AdminStudentAccountManagementScreen extends ConsumerStatefulWidget {
  const AdminStudentAccountManagementScreen({super.key});

  @override
  ConsumerState<AdminStudentAccountManagementScreen> createState() =>
      _AdminStudentAccountManagementScreenState();
}

class _AdminStudentAccountManagementScreenState
    extends ConsumerState<AdminStudentAccountManagementScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isCreating = false;
  String? _deletingStudentId;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (_isCreating) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final service = ref.read(studentAccountServiceProvider);
    setState(() {
      _isCreating = true;
    });
    try {
      await service.createStudent(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      _usernameController.clear();
      _passwordController.clear();
      ref.invalidate(studentAccountsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Akun siswa berhasil dibuat.")),
      );
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _deleteStudent(String studentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Hapus akun siswa"),
          content: const Text(
            "Akun siswa beserta data ujian terkait akan terhapus. Lanjutkan?",
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Hapus"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingStudentId = studentId;
    });

    final service = ref.read(studentAccountServiceProvider);
    try {
      await service.deleteStudent(studentId);
      ref.invalidate(studentAccountsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Akun siswa berhasil dihapus.")),
      );
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingStudentId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Student Account Management")),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppCard(
              title: "Buat Akun Siswa",
              subtitle: "Admin menyiapkan username dan password peserta ujian.",
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: "Username siswa",
                        hintText: "contoh: siswa01",
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? "";
                        if (text.isEmpty) {
                          return "Username wajib diisi";
                        }
                        if (text.length < 3) {
                          return "Username minimal 3 karakter";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        hintText: "Minimal 6 karakter",
                      ),
                      validator: (value) {
                        final text = value ?? "";
                        if (text.isEmpty) {
                          return "Password wajib diisi";
                        }
                        if (text.length < 6) {
                          return "Password minimal 6 karakter";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: "Buat Akun Siswa",
                      loading: _isCreating,
                      onPressed: _createStudent,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  "Daftar Akun Siswa",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () => ref.invalidate(studentAccountsProvider),
                  child: const Text("Segarkan"),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: studentsAsync.when(
                data: (students) {
                  if (students.isEmpty) {
                    return const AppCard(
                      title: "Belum ada akun siswa",
                      subtitle: "Tambahkan akun siswa untuk bisa login ujian.",
                    );
                  }

                  return ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = students[index];
                      final deleting = _deletingStudentId == item.id;
                      return AppCard(
                        title: item.username,
                        subtitle: "Role: ${item.role}",
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AppButton(
                            label: "Hapus",
                            variant: AppButtonVariant.secondary,
                            loading: deleting,
                            onPressed:
                                deleting ? null : () => _deleteStudent(item.id),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AppCard(
                  title: "Gagal memuat akun siswa",
                  subtitle: error.toString(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: "Kembali ke Dashboard",
              onPressed: () => context.go("/admin/dashboard"),
            ),
          ],
        ),
      ),
    );
  }
}
