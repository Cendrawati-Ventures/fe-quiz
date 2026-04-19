import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../app/theme/spacing.dart";
import "../../../core/network/api_error.dart";
import "../../../shared/components/app_button.dart";
import "../../../shared/components/app_card.dart";
import "../service/student_account_service.dart";
import "widgets/admin_layout.dart";

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

  Future<void> _deleteStudent({
    required String studentId,
    required String username,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Hapus akun siswa"),
          content: Text(
            "Akun \"$username\" akan dihapus permanen.\n\n"
            "Semua hasil ujian siswa ini juga akan ikut terhapus dan tidak bisa dikembalikan. Lanjutkan?",
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Batal"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Ya, Hapus"),
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

    return AdminLayout(
      title: "Kelola Akun Siswa",
      subtitle: "Tambah, hapus, dan cek akun peserta ujian.",
      activeSection: AdminSection.students,
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
                      labelText: "Kata Sandi",
                      hintText: "Minimal 6 karakter",
                    ),
                    validator: (value) {
                      final text = value ?? "";
                      if (text.isEmpty) {
                        return "Kata sandi wajib diisi";
                      }
                      if (text.length < 6) {
                        return "Kata sandi minimal 6 karakter";
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
                      subtitle: "Peran: ${item.role}",
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AppButton(
                          label: "Hapus",
                          variant: AppButtonVariant.secondary,
                          loading: deleting,
                          onPressed: deleting
                              ? null
                              : () => _deleteStudent(
                                    studentId: item.id,
                                    username: item.username,
                                  ),
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
        ],
      ),
    );
  }
}
