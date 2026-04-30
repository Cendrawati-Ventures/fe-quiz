import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _lastUpdated = '30 April 2026';
  static const String _contactEmail = 'rifkirusdisatmaputra@gmail.com';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kebijakan Privasi'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Kebijakan Privasi Quiz QTA',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Terakhir diperbarui: $_lastUpdated',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: 'Data yang dikumpulkan',
                body: 'Aplikasi dapat mengumpulkan data akun, data sesi ujian, '
                    'aktivitas anti-cheat, data perangkat, serta log teknis '
                    'yang diperlukan untuk operasional layanan.',
              ),
              _buildSection(
                context,
                title: 'Izin kamera dan mikrofon',
                body: 'Aplikasi menggunakan izin kamera '
                    '(android.permission.CAMERA) dan mikrofon '
                    '(android.permission.RECORD_AUDIO) ketika fitur monitoring '
                    'ujian aktif. Izin diminta saat fitur digunakan untuk '
                    'verifikasi peserta dan menjaga integritas ujian.',
              ),
              _buildSection(
                context,
                title: 'Tujuan penggunaan data',
                body: 'Data digunakan untuk proses login, pelaksanaan ujian, '
                    'monitoring keamanan ujian, pencegahan kecurangan, '
                    'penanganan gangguan sistem, dan pemenuhan kewajiban hukum.',
              ),
              _buildSection(
                context,
                title: 'Pembagian data',
                body: 'Data tidak dijual. Data dapat diproses terbatas oleh '
                    'penyedia layanan pihak ketiga yang mendukung '
                    'komunikasi real-time, penyimpanan, dan keandalan layanan.',
              ),
              _buildSection(
                context,
                title: 'Keamanan dan retensi',
                body:
                    'Kami menerapkan perlindungan teknis dan organisasi untuk '
                    'mencegah akses tidak sah. Data disimpan selama diperlukan '
                    'untuk operasional, keamanan, audit, dan kepatuhan hukum.',
              ),
              _buildSection(
                context,
                title: 'Hak pengguna',
                body:
                    'Pengguna dapat meminta akses, perbaikan, atau penghapusan '
                    'data sesuai ketentuan yang berlaku melalui kontak privasi.',
              ),
              _buildSection(
                context,
                title: 'Kontak privasi',
                body: 'Email: $_contactEmail',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E6ED)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
