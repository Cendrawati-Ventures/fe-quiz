import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../app/theme/spacing.dart";
import "../../../core/network/api_error.dart";
import "../../../shared/components/app_button.dart";
import "../../../shared/components/app_card.dart";
import "../service/classroom_service.dart";
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
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _rollNumberController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedClassId;

  bool _isCreating = false;
  String? _deletingStudentId;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _rollNumberController.dispose();
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
        fullName: _optionalTrimmed(_fullNameController.text),
        classId: _selectedClassId,
        rollNumber: _optionalTrimmed(_rollNumberController.text),
      );
      _usernameController.clear();
      _passwordController.clear();
      _fullNameController.clear();
      _rollNumberController.clear();
      _selectedClassId = null;
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

  String? _optionalTrimmed(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
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
    final classesAsync = ref.watch(classListProvider);

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
                    textInputAction: TextInputAction.next,
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
                  TextFormField(
                    controller: _fullNameController,
                    textInputAction: TextInputAction.next,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: "Nama Siswa (opsional)",
                      hintText: "contoh: Rusdy Setiawan",
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? "";
                      if (text.length > 120) {
                        return "Nama maksimal 120 karakter";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  classesAsync.when(
                    data: (classes) {
                      return DropdownButtonFormField<String?>(
                        initialValue: _selectedClassId,
                        decoration: const InputDecoration(
                          labelText: "Kelas (opsional)",
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text("Belum ditetapkan"),
                          ),
                          ...classes.map(
                            (classRoom) => DropdownMenuItem<String?>(
                              value: classRoom.id,
                              child: Text(classRoom.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedClassId = value;
                          });
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (error, _) => Text(
                      'Daftar kelas gagal dimuat: $error',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _rollNumberController,
                    textInputAction: TextInputAction.done,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: "No Absen (opsional)",
                      hintText: "contoh: 12",
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? "";
                      if (text.length > 30) {
                        return "No absen maksimal 30 karakter";
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
                    final displayName = item.fullName?.trim().isNotEmpty == true
                        ? item.fullName!.trim()
                        : item.username;
                    final className = item.className?.trim();
                    final rollNumber = item.rollNumber?.trim();

                    return AppCard(
                      title: displayName,
                      subtitle:
                          "Username: ${item.username} - Peran: ${item.role}",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            "Kelas: ${(className == null || className.isEmpty) ? '-' : className}",
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            "No Absen: ${(rollNumber == null || rollNumber.isEmpty) ? '-' : rollNumber}",
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Align(
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
                        ],
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
