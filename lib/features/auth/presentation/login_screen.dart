import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../state/auth_provider.dart';

enum _LandingRole { siswa, admin }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  _LandingRole _selectedRole = _LandingRole.siswa;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref.read(authProvider.notifier).login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      context.go(authState.isAdmin ? '/admin/dashboard' : '/exam');
      return;
    }

    if (authState.errorMessage != null && authState.errorMessage!.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authState.errorMessage!)));
    }
  }

  String get _usernameHint {
    return _selectedRole == _LandingRole.siswa
        ? 'Masukkan username atau NIS'
        : 'Masukkan username admin';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFE1E4CF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1024;
            final isPhone = constraints.maxWidth < 700;
            final maxWidth =
                constraints.maxWidth > 1260 ? 1260.0 : constraints.maxWidth;

            if (isWide) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _buildIdentityPanel(
                            textTheme,
                            compact: false,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: _buildLoginPanel(
                            authState,
                            compact: false,
                            mobileFirst: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isPhone ? 560 : 760),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    isPhone ? AppSpacing.sm : AppSpacing.md,
                    isPhone ? AppSpacing.sm : AppSpacing.md,
                    isPhone ? AppSpacing.sm : AppSpacing.md,
                    (isPhone ? AppSpacing.sm : AppSpacing.md) +
                        MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    children: <Widget>[
                      if (isPhone) ...<Widget>[
                        _buildLoginPanel(
                          authState,
                          compact: true,
                          mobileFirst: true,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildIdentityCompactPhone(textTheme),
                      ] else ...<Widget>[
                        _buildIdentityPanel(textTheme, compact: true),
                        const SizedBox(height: AppSpacing.md),
                        _buildLoginPanel(
                          authState,
                          compact: true,
                          mobileFirst: false,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIdentityPanel(TextTheme textTheme, {required bool compact}) {
    final titleFontSize = compact ? 32.0 : 46.0;
    final logoWrapSize = compact ? 120.0 : 150.0;
    final logoSize = compact ? 96.0 : 126.0;

    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF4DB956), Color(0xFF1D7E4A)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33223620),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB7E974).withValues(alpha: 0.32),
              ),
            ),
          ),
          Positioned(
            left: -100,
            bottom: -130,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8ED7A5).withValues(alpha: 0.32),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: Text(
                  'Sekolah Penyelenggara',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: logoWrapSize,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Container(
                      height: logoSize,
                      width: logoSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF6F6F2),
                        border: Border.all(
                          color: const Color(0xFF19A453),
                          width: 4,
                        ),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 56,
                        color: Color(0xFF218D4D),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white24),
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                          child: Text(
                            'SEKOLAH BALI Q_TA',
                            style: textTheme.labelLarge?.copyWith(
                              color: const Color(0xFFEFFBEF),
                              letterSpacing: 2.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Quiz Bali Q_Ta',
                          style: textTheme.headlineMedium?.copyWith(
                            color: const Color(0xFFF3FFF1),
                            fontWeight: FontWeight.w700,
                            fontSize: titleFontSize,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Bali Q_Ta Satu Hati, Satu Jiwa, Satu Cinta',
                          style: textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFFE8FDE8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Silakan masuk untuk mulai ujian. '
                          'Halaman ini dapat dipakai guru maupun siswa.',
                          style: textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFFE3F8E5),
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding:
                    EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1EC).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildInfoLine(
                      icon: Icons.location_on_rounded,
                      title: 'ALAMAT',
                      value: 'Jalan Gaga, Desa Keramas, Kecamatan Blahbatuh, '
                          'Kabupaten Gianyar, Provinsi Bali',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildInfoLine(
                      icon: Icons.call_rounded,
                      title: 'KONTAK',
                      value: '(0361)953999 / 085738938887',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _buildMetaInfo(
                            label: 'NPSN',
                            value: '50105534',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildMetaInfo(
                            label: 'KECAMATAN',
                            value: 'Blahbatuh',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _buildMetaInfo(
                            label: 'KABUPATEN',
                            value: 'Gianyar',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildMetaInfo(
                            label: 'PROVINSI',
                            value: 'Bali',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Siapkan paket ujian di halaman admin '
                        'sebelum siswa masuk.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFE9FBEA),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  'QUIZ-BALI-Q_TA  V1.0.0',
                  style: textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    letterSpacing: 1.6,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCompactPhone(TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF4DB956), Color(0xFF1D7E4A)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x29223620),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF6F6F2),
              border: Border.all(color: const Color(0xFF19A453), width: 3),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 28,
              color: Color(0xFF218D4D),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Quiz Bali Q_Ta',
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Satu Hati, Satu Jiwa, Satu Cinta',
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFE9FBEA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Portal login untuk guru dan siswa.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFE3F8E5),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'QUIZ-BALI-Q_TA V1.0.0',
                  style: textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPanel(
    AuthState authState, {
    required bool compact,
    required bool mobileFirst,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final arenaTitleSize = mobileFirst ? 28.0 : (compact ? 32.0 : 40.0);
    final panelPadding = mobileFirst ? AppSpacing.md : AppSpacing.lg;

    return Container(
      padding: EdgeInsets.all(panelPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(mobileFirst ? 18 : 22),
        color: const Color(0xFFF5F4EE),
        border: Border.all(color: const Color(0xFFD8D0BD)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Masuk ke Sistem Ujian',
                    style: textTheme.headlineMedium?.copyWith(
                      fontSize: arenaTitleSize,
                      color: const Color(0xFF53462D),
                    ),
                  ),
                ),
                if (!mobileFirst)
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFF1ECE0),
                      border: Border.all(color: const Color(0xFFD0C5AB)),
                    ),
                    child: const Icon(
                      Icons.question_mark_rounded,
                      size: 18,
                      color: Color(0xFF675837),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pilih peran, lalu masuk ke sistem ujian.',
              style: textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF7B6848),
              ),
            ),
            SizedBox(height: mobileFirst ? AppSpacing.md : AppSpacing.lg),
            DropdownButtonFormField<_LandingRole>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(labelText: 'Masuk sebagai'),
              items: const <DropdownMenuItem<_LandingRole>>[
                DropdownMenuItem(
                  value: _LandingRole.siswa,
                  child: Text('Siswa'),
                ),
                DropdownMenuItem(
                  value: _LandingRole.admin,
                  child: Text('Admin'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedRole = value;
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username / NIS',
                hintText: _usernameHint,
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Username wajib diisi';
                }
                if (trimmed.length < 3) {
                  return 'Username minimal 3 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Kata Sandi',
                hintText: 'Masukkan kata sandi',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  tooltip: _obscurePassword
                      ? 'Lihat kata sandi'
                      : 'Sembunyikan kata sandi',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _onLoginPressed(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kata sandi wajib diisi';
                }
                if (value.length < 6) {
                  return 'Kata sandi minimal 6 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _buildActionButton(
              label: 'Masuk',
              isLoading: authState.isLoading,
              onPressed: _onLoginPressed,
              fullWidth: true,
            ),
            if (authState.errorMessage != null &&
                authState.errorMessage!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                authState.errorMessage!,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Text(
                mobileFirst
                    ? 'Mode ringan, cocok untuk perangkat sekolah.'
                    : 'Mode ringan, cocok untuk laptop sekolah.',
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF76684D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
    required bool fullWidth,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF14A34F), Color(0xFF6AC48F)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x3327A053),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
      ),
    );
  }

  Widget _buildInfoLine({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFF1A9A56),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF495041),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF384039),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaInfo({required String label, required String value}) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: const Color(0xFF4A5141),
            letterSpacing: 3.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF313A30),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
