# Exam Security Checklist

Dokumen ini dipakai untuk cek cepat fitur keamanan ujian pada aplikasi Flutter (`Frontend`).

## 1) Kebutuhan Setup API / Platform

- [x] Firebase CLI terpasang (`firebase --version`)
- [x] FlutterFire CLI terpasang (`flutterfire --version`)
- [x] Firebase project Android terhubung ke app (`google-services.json` + `lib/firebase_options.dart`)
- [x] Realtime Database aktif dan rules file tersedia (`database.rules.json`)
- [x] Backend punya kredensial Agora:
  - `AGORA_APP_ID`
  - `AGORA_APP_CERTIFICATE`
  - `AGORA_TOKEN_TTL_SECONDS`
- [x] Backend punya konfigurasi Firebase RTDB:
  - `FIREBASE_DATABASE_URL`
  - `FIREBASE_PROJECT_ID`

## 2) Checklist Fitur Keamanan

| Status | Fitur | Fungsi | Lokasi Kode | Cara Pakai / Uji |
|---|---|---|---|---|
| [x] | Monitoring video (Agora) | Menghubungkan kamera siswa ke channel monitoring | `lib/features/exam_monitoring/services/agora_service.dart` | Mulai ujian, buka monitoring, pastikan video lokal tampil dan status koneksi `connected`. |
| [x] | Monitoring auto-launch saat mulai attempt | Memaksa user masuk layar monitoring minimal sekali di awal attempt | `lib/features/exam/presentation/exam_screen.dart` (`_syncMonitoringBootstrap`) | Mulai ujian baru, layar monitoring harus otomatis terbuka sekali. |
| [x] | Secure screen flag | Cegah screenshot/rekam layar di mode ujian (best effort platform) | `lib/features/exam/presentation/exam_screen.dart`, `lib/core/device/screen_security.dart`, `android/app/src/main/kotlin/.../MainActivity.kt` | Saat ujian aktif, coba screenshot/screen recording dari device. |
| [x] | Rekam mikrofon per chunk | Rekaman audio 30 detik per potongan untuk proctoring | `lib/features/exam/presentation/exam_screen.dart` | Mulai ujian, tunggu >30 detik, cek endpoint upload audio chunk terpanggil di backend. |
| [x] | Event app background | Catat ketika aplikasi keluar ke background | `lib/features/exam/state/exam_state.dart` | Saat ujian, pindah app (home/recent apps), pastikan event proctoring terkirim. |
| [x] | Event idle | Catat saat tidak ada interaksi melebihi timeout | `lib/features/exam/state/exam_state.dart`, `lib/core/device/idle_service.dart` | Diamkan layar tanpa sentuhan, tunggu timeout, pastikan warning/event muncul. |
| [x] | Event noise | Catat kebisingan lingkungan dari mic | `lib/features/exam/state/exam_state.dart`, `lib/core/device/noise_service.dart` | Buat suara keras saat ujian, cek warning/event noise. |
| [x] | Event `tab_switch` saat keluar layar ujian | Catat user keluar dari halaman ujian | `lib/features/exam/presentation/exam_screen.dart` | Tekan back lalu konfirmasi keluar, cek event `tab_switch`. |
| [x] | Violation saat mic dimatikan | Tambah pelanggaran dan kirim signal proctoring | `lib/features/exam_monitoring/presentation/student_exam_screen.dart`, `lib/features/exam_monitoring/controllers/student_exam_controller.dart` | Di layar monitoring tekan `Mute Mic`, lihat violations naik + event terkirim. |
| [x] | Violation saat kamera dimatikan | Tambah pelanggaran dan kirim signal proctoring | `lib/features/exam_monitoring/presentation/student_exam_screen.dart`, `lib/features/exam_monitoring/controllers/student_exam_controller.dart` | Di layar monitoring tekan `Hide Cam`, lihat violations naik + event terkirim. |
| [x] | Presence & heartbeat Firebase | Status realtime siswa: `ACTIVE/LEFT_APP/OFFLINE/FINISHED`, heartbeat, reconnect | `lib/features/exam_monitoring/services/realtime_status_service.dart` | Putuskan jaringan lalu sambungkan lagi, cek status realtime terbarui. |
| [x] | Firebase rules diperketat | Batasi write agar hanya schema presence yang valid | `database.rules.json` | Deploy rules lalu uji write invalid (field tambahan/format salah) harus ditolak. |

## 3) Yang Belum Ada (Lanjutan)

| Status | Fitur | Catatan |
|---|---|---|
| [ ] | Deteksi gesture AI (face gaze/head pose/hand landmark) | Belum ada integrasi CV/ML (MediaPipe/ML Kit/TensorFlow). |
| [ ] | Kiosk mode penuh (lock task) | Belum ada pembatasan level OS untuk keluar aplikasi secara penuh. |

## 4) Langkah Verifikasi Cepat (Smoke Test)

1. Login sebagai siswa.
2. Mulai ujian.
3. Pastikan monitoring terbuka otomatis sekali.
4. Kembali ke layar ujian, jawab 1-2 soal.
5. Biarkan idle hingga warning muncul.
6. Buat kebisingan, cek warning noise.
7. Buka monitoring, mute mic dan hide cam, cek violations naik.
8. Kembali, tekan back + konfirmasi keluar, cek event `tab_switch`.
9. Login admin, cek ringkasan monitoring/proctoring dan audio chunk.