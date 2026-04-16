# PRD Frontend Mobile - Online Exam System (Android-first, Low-end)

## 0. Prinsip Wajib (Mengikat)
1. Backend (`Node.js + Express + PostgreSQL + TypeORM`) adalah source of truth tunggal.
2. Frontend hanya melakukan rendering UI, manajemen state UI/sesi, dan pengiriman data ke API.
3. Frontend **tidak** menghitung `score`, **tidak** menentukan pelanggaran anti-cheat, **tidak** mengevaluasi `attempt_limit`.
4. Nama field payload/request/response harus sama persis dengan backend (contoh: `attempt_limit`, bukan `attemptLimit`).
5. Frontend **tidak** menyimpan `correct_answer`.
6. Semua validasi penting tetap di backend.
7. Semua keputusan final terkait scoring, anti-cheat, kelulusan, risk level, dan attempt validity tetap di backend.

## 1. Mobile App Architecture

### 1.1 Pilihan Framework
Pilih **Flutter** (direkomendasikan) karena:
- Performa stabil di Android low-end.
- Kontrol render dan rebuild lebih granular.
- Lebih aman dari jitter JS-thread pada device RAM kecil.

### 1.2 Layering
- `presentation`: screen, widget, interaction.
- `state`: state holder + state transition.
- `service/api`: HTTP client, endpoint call, retry policy.
- `model`: DTO/entity sesuai backend (nama field backend dipertahankan).

### 1.3 Struktur Folder (Feature-based)
```txt
lib/
  app/
    app.dart
    router.dart
    route_guard.dart
    theme/
      colors.dart
      typography.dart
      spacing.dart
  core/
    network/
      api_client.dart
      api_error.dart
    storage/
      secure_storage.dart
      local_db.dart
    queue/
      outbox_queue.dart
    device/
      lifecycle_service.dart
      idle_service.dart
      noise_service.dart
    utils/
      debounce.dart
      time_sync.dart
  features/
    auth/
      model/
      service/
      state/
      presentation/
    exam/
      model/
      service/
      state/
      presentation/
    attempt/
      model/
      service/
      state/
    answer/
      model/
      service/
      state/
    result/
      model/
      service/
      state/
    proctoring_event/
      model/
      service/
      state/
    subject/
      model/
      service/
      state/
      presentation/
    admin/
      dashboard/
      subject_management/
      question_management/
      result_monitoring/
  shared/
    components/
      app_button.dart
      app_card.dart
      question_card.dart
      option_item.dart
      timer_widget.dart
      progress_bar.dart
      bottom_action_bar.dart
      connection_chip.dart
      warning_banner.dart
```

## 2. State Management (Detail Wajib)

Gunakan `Riverpod` (`StateNotifier`/`Notifier`) dengan prinsip granular provider.

### 2.1 Global State
- `auth_state`: token, user session, auth status.
- `user_state`: profil `User` aktif.
- `connectivity_state`: online/offline.
- `app_lifecycle_state`: foreground/background.
- `theme_role_state`: `admin` atau `student` (untuk color rules per screen).

### 2.2 Screen State (Ephemeral)
- Loading, error, selected tab, search query, filter, dialog state.
- Tidak disimpan permanen.
- Scope per screen agar re-render kecil.

### 2.3 Exam Session State (Critical)
State paling kritikal, harus tahan rebuild, background, reconnect.
- `exam_session_state` berisi:
  - `exam`
  - `attempt`
  - `current_question_index`
  - `answers_by_question_id`
  - `pending_answer_queue`
  - `timer_state` (server-synced)
  - `proctoring_buffer`
  - `submit_state`
  - `connection_state`
- Persist lokal berkala (setiap perubahan jawaban dan event penting).
- Restore otomatis saat app reopen bila `attempt` belum submitted.

### 2.4 State per Entitas Backend
- `user_state` -> `User`
- `subject_state` -> `Subject`
- `exam_state` -> `Exam`
- `attempt_state` -> `Attempt`
- `answer_state` -> `Answer`
- `result_state` -> `Result`
- `proctoring_event_state` -> `ProctoringEvent`

## 3. UI/UX Foundation (Wajib Ikut Style Guide)

### 3.1 Color Tokens
- `bg.base #F4F6FA`
- `bg.surface #FFFFFF`
- `text.primary #111827`
- `text.secondary #475467`
- `border.default #D0D5DD`
- `admin.primary #0B5FFF`
- `student.primary #0E9F6E`
- `state.success #16A34A`
- `state.warning #D97706`
- `state.danger #DC2626`
- `state.info #0EA5E9`

Aturan:
- Screen admin hanya tema biru.
- Screen siswa hanya tema hijau.
- Tidak campur warna primary admin/siswa dalam satu screen.

### 3.2 Typography
- Heading: `Manrope`
- Body: `IBM Plex Sans`
- Timer: `JetBrains Mono`

### 3.3 Mobile Layout Rules
- Card-based UI.
- Bottom navigation.
- Sticky CTA.
- Target sentuh minimum 44dp.
- Kontras teks minimal WCAG AA untuk keterbacaan di layar murah.

## 4. Screen Breakdown (Mobile)

### 4.1 AUTH
- `LoginScreen`
  - Input kredensial.
  - Action login API.
  - Simpan token aman.
  - Redirect sesuai role.

### 4.2 SISWA (Prioritas Utama)
- `ExamListScreen`
  - Daftar ujian aktif/riwayat ringkas.
  - Card status ujian.
- `ExamDetailStartScreen`
  - Detail exam, aturan, attempt info.
  - CTA `Start`.
- `ExamScreen` (super kritikal)
  - Timer sticky, question, options, nav, submit sticky.
- `ResultScreen`
  - Tampilkan `result` dari backend (`score`, `risk_level`, status).

### 4.3 ADMIN (Mobile Version)
- `AdminDashboardScreen`
  - Ringkasan total exam/attempt/result.
- `SubjectManagementScreen` (simplified)
  - List/create/edit sederhana.
- `QuestionManagementScreen` (optional basic)
  - List by subject, create/edit minimum.
- `ResultMonitoringScreen`
  - Monitor hasil dan indikator risiko.

### 4.4 Navigation Flow (Mandatory)
#### Siswa Flow
`LoginScreen` -> `ExamListScreen` -> `ExamDetailStartScreen` -> `ExamScreen` -> `ResultScreen`

#### Admin Flow
`LoginScreen` -> `AdminDashboardScreen` -> (`SubjectManagementScreen` / `QuestionManagementScreen` / `ResultMonitoringScreen`)

#### Routing Rules
- Gunakan route guard berbasis `auth_state` dan role `User`.
- Setelah `submitExam()` sukses, route wajib pindah ke `ResultScreen` dan stack exam dibersihkan.
- Saat ada `attempt.status == "in_progress"`, route guard harus memprioritaskan `ExamScreen`.
- Cegah state leak antar screen dengan provider scope per route.

## 5. Exam Screen (Super Detail)

### 5.1 Layout
1. Header sticky:
   - Judul ringkas exam.
   - `TimerWidget` monospace (`JetBrains Mono`).
2. Progress:
   - `ProgressBar` (nomor soal dan persentase).
3. Question area:
   - `QuestionCard`.
4. Option area:
   - `OptionItem` list.
5. Navigation:
   - Tombol `Previous` dan `Next`.
6. Sticky bottom:
   - `BottomActionBar` berisi `Submit`.

### 5.2 Behavior Kritis
- Pilih jawaban langsung update `answers_by_question_id` lokal.
- Debounce save per soal (misal 500-800ms).
- Setelah debounce, panggil `saveAnswer()`.
- Jika gagal kirim, tandai pending dan masuk queue.
- State tidak hilang saat rebuild/background/reopen.
- Submit disable saat masih proses submit, bukan saat ada pending answer (pending tetap diflush sebelum submit call final).

### 5.3 Question Type Handling
- `single`: satu opsi aktif.
- `multi`: banyak opsi aktif.
- `group`: render parent + sub-question; simpan mengikuti struktur payload backend.
- Frontend hanya format payload sesuai API, bukan menilai benar/salah.

### 5.4 Proctoring Triggers (Wajib)
- App background -> kirim event `app_background`.
- Idle user -> kirim event `idle`.
- Noise sampling periodik -> kirim event `noise` per interval.
- Frontend hanya kirim event mentah + metadata; backend memutuskan risk/cheat.

### 5.5 Timer
- Timer sinkron server dari timestamp backend (saat fetch/start).
- Simpan `server_offset_ms` di `exam_session_state`.
- Hitung sisa waktu dari waktu server, bukan device local murni.
- Timer jalan dari session controller, bukan widget local state.
- Rebuild screen tidak boleh reset timer.

### 5.6 Submit Flow (Mandatory)
Alur submit wajib:
1. User klik `Submit`.
2. Muncul modal konfirmasi:
   - "Apakah kamu yakin ingin mengumpulkan ujian?"
   - "Jawaban belum lengkap: X soal."
3. Jika user konfirmasi:
   - Flush `pending_answer_queue`.
   - Panggil `submitExam()`.
4. Jika sukses -> navigate ke `ResultScreen`.
5. Jika gagal -> tampilkan modal retry (blocking).

## 6. API Integration Mapping

| Endpoint | Function | Tujuan |
|---|---|---|
| `POST /attempts/start` | `startAttempt()` | Membuat `Attempt` ujian |
| `POST /answers` | `saveAnswer()` | Simpan/ubah jawaban |
| `POST /proctoring/events` | `sendEvent()` | Kirim event proctoring |
| `POST /attempts/:id/submit` | `submitExam()` | Submit attempt final |

Aturan integrasi:
- Gunakan field payload persis backend.
- Error 4xx/5xx ditampilkan sebagai status UI, bukan diproses jadi rule baru.
- Submit retry aman (idempotent dari sisi backend contract).
- Frontend tidak mengubah semantik field backend.

## 7. Component System (Reusable Mobile)

- `AppButton`
  - Props: `label`, `variant`, `loading`, `disabled`, `onPressed`.
- `AppCard`
  - Props: `title`, `subtitle`, `child`, `status`.
- `QuestionCard`
  - Props: `question`, `question_index`, `total_question`.
- `OptionItem`
  - Props: `option`, `selected`, `multi_select`, `onTap`.
- `TimerWidget`
  - Props: `remaining_seconds`, `is_warning`.
- `ProgressBar`
  - Props: `current`, `total`, `value`.
- `BottomActionBar`
  - Props: `primary_action`, `secondary_action`, `sticky`.
- `ConnectionChip`
  - Props: `is_online`, `sync_status`.
- `WarningBanner`
  - Props: `type`, `message`, `is_visible`.

## 8. Interaction Flow (Contoh Jawaban)

1. User tap opsi jawaban.
2. `answer_state` lokal update instan.
3. Debounce timer mulai.
4. Debounce selesai -> `saveAnswer()` dipanggil.
5. Jika sukses -> tandai synced.
6. Jika gagal -> simpan ke `outbox_queue`, status pending, retry background.
7. UI tetap responsif, user lanjut ke soal berikut.

## 9. Proctoring Frontend Logic

### 9.1 App Lifecycle Listener
- Listen `resumed`, `inactive`, `paused`, `detached`.
- Saat pindah ke background, enqueue `ProctoringEvent`.
- Saat resume, kirim `app_foreground` jika kontrak backend mendukung.

### 9.2 Idle Timer
- Reset idle counter pada interaksi sentuh/scroll/tap.
- Jika melewati threshold (misal dari backend config), kirim event `idle`.
- Cooldown agar tidak spam event idle berturut-turut.

### 9.3 Noise Sampling
- Sampling amplitudo periodik frekuensi rendah agar hemat baterai.
- Kirim ringkasan metadata (`amplitude`, `sample_time`, `device_state`) tanpa menyimpan audio mentah.
- Interval kirim disesuaikan config backend.

### 9.4 Retry Strategy
- Semua `proctoring_event` masuk queue jika gagal.
- Retry exponential backoff + jitter.
- Hard cap retry per item, sisanya tetap disimpan sampai network stabil.
- Prioritas flush: `answer` -> `proctoring_event` -> `submit` pre-check flush.

### 9.5 Proctoring Feedback (UI)
- Saat tab switch/background terdeteksi:
  - tampilkan warning ringan non-blocking ("Aplikasi berpindah ke background terdeteksi").
- Saat idle:
  - tampilkan warning ringan ("Kamu tidak aktif").
- Saat noise tinggi:
  - tampilkan indikator mic level sederhana pada header.
- Feedback bersifat deterrence/transparansi, bukan vonis kecurangan.

## 10. Performance Strategy (Wajib)

- Minim re-render dengan provider granular per widget.
- Gunakan `const` widget dan memoized selectors.
- Lazy load/render soal (hanya current + near neighbors).
- Hindari global state besar yang memuat seluruh UI ephemeral.
- Parse JSON besar di isolate bila payload exam berat.
- Batasi animasi berat dan efek visual kompleks.
- Gunakan list virtualization (`ListView.builder`).
- Hindari logging verbose di release.
- Pantau memory footprint pada device RAM kecil.

## 11. Offline / Bad Network Strategy

- Implement `outbox_queue` lokal persisten.
- `saveAnswer` gagal -> queue dengan dedup per `attempt_id + question_id` (latest payload wins).
- Retry otomatis saat koneksi kembali.
- UI tampilkan indikator sync ringan, tidak mengganggu ujian.
- Saat submit:
  - Flush pending answer dulu.
  - Kirim `submitExam()`.
  - Jika timeout/network fail, retry endpoint submit yang sama.
- Submit harus idempotent berdasarkan kontrak backend (`attempt` yang sama tidak menghasilkan submit ganda).

## 12. Loading State

- Login -> full screen loading.
- Fetch exam list/detail -> skeleton card.
- Start attempt -> blocking loading.
- Save answer -> non-blocking (hanya indikator sync kecil).
- Submit -> blocking loading sampai sukses/gagal.

## 13. Error Handling UX

- Network error umum:
  - tampilkan snackbar ringan non-blocking.
- Save answer gagal:
  - tampilkan indikator kecil status sync (`pending`/`retrying`).
- Submit gagal:
  - tampilkan modal retry (blocking) dengan aksi `Retry Submit`.
- Fatal error (state korup/response tidak valid):
  - tampilkan fallback screen + aksi restart session.

## 14. Empty State

- Exam kosong:
  - "Belum ada ujian tersedia."
- Result kosong:
  - "Kamu belum mengerjakan ujian."
- Empty state harus tetap menyediakan CTA kembali/refetch.

## 15. Session Recovery

Skenario wajib: app crash/kill saat ujian berlangsung.

Saat app dibuka:
1. Cek sesi lokal + panggil refresh attempt aktif.
2. Jika `attempt.status == "in_progress"`:
   - langsung redirect ke `ExamScreen`,
   - restore `exam_session_state`,
   - sync ulang answer pending dan proctoring queue ke server.
3. Jika `attempt.status` bukan `in_progress`:
   - arahkan ke flow normal (`ExamListScreen`/`ResultScreen` sesuai data backend).

## 16. Security UX

- Disable screenshot/screen recording di `ExamScreen` (opsional Android via secure flag).
- Blur app content saat background/app switcher.
- Disable copy-paste pada input yang relevan selama exam mode.
- Semua security UX adalah mitigasi UI; keputusan pelanggaran tetap backend.

## 17. Exam Runtime Guardrails (Upgrade Level)

### 17.1 Exam Mode Lock
- Saat `attempt.status == "in_progress"`:
  - disable back button langsung,
  - jika user paksa keluar, tampilkan confirm exit modal.

### 17.2 Connection Indicator
- Tampilkan status `Online` / `Offline`.
- Tampilkan status sinkronisasi (`Synced`, `Pending`, `Retrying`) di header/bottom bar.

### 17.3 Auto Submit on Timeout
- Jika timer mencapai `00:00`:
  - lock interaksi jawaban,
  - auto panggil `submitExam()`,
  - bila jaringan gagal, pakai retry submit idempotent sampai respons backend diterima.

## 18. Checklist Task (Wajib)

### AUTH
[ ] UI login
[ ] API login
[ ] token storage

### EXAM
[ ] fetch exam
[ ] start attempt
[ ] render soal
[ ] save answer
[ ] timer
[ ] submit

### PROCTORING
[ ] detect app background
[ ] detect idle
[ ] send event
[ ] retry
[ ] tampilkan warning feedback UI

### RESULT
[ ] tampilkan score
[ ] tampilkan risk level

### SESSION & SECURITY
[ ] session recovery saat crash
[ ] disable screenshot pada exam
[ ] connection indicator + sync status
[ ] auto submit on timeout

## 19. Definition of Done

- Semua flow ujian berjalan end-to-end tanpa error fungsional.
- Tidak ada logic penting backend yang dipindah ke client.
- Tidak ada penyimpanan `correct_answer` di client.
- Tidak ada crash signifikan pada Android low-end.
- Semua endpoint terintegrasi sesuai kontrak backend.
- Proctoring event terkirim dengan retry saat jaringan buruk.
- Timer akurat dan tidak reset saat rebuild/background-resume.
- Navigation flow siswa/admin konsisten dan tidak leak state antar screen.
- UX tetap responsif pada kondisi RAM kecil dan koneksi tidak stabil.
