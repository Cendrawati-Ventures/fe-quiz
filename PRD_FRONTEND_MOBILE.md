# PRD Frontend Mobile - Online Exam System (Android-first, Low-end)

## 0. Prinsip Wajib (Mengikat)
1. Backend (`Node.js + Express + PostgreSQL + TypeORM`) adalah source of truth tunggal.
2. Frontend hanya melakukan rendering UI, manajemen state UI/sesi, dan pengiriman data ke API.
3. Frontend **tidak** menghitung `score`, **tidak** menentukan pelanggaran anti-cheat, **tidak** mengevaluasi `attemptLimit`.
4. Nama field payload/request/response harus sama persis dengan kontrak endpoint backend (API JSON saat ini `camelCase`; notasi domain DB tetap `snake_case`).
5. Frontend **tidak** menyimpan `correctAnswer` (`correct_answer` di level DB/backend internal).
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
- `examSessionState` berisi:
  - `exam`
  - `attempt`
  - `currentQuestionIndex`
  - `answersByQuestionId`
  - `pendingAnswerQueue`
  - `remainingSeconds` (server-synced)
  - `proctoringBuffer`
  - `submitState`
  - `connectionState`
- Persist lokal berkala (setiap perubahan jawaban dan event penting).
- Restore otomatis saat app reopen bila `attempt` belum submitted.

### 2.4 State per Entitas Backend
- `user_state` -> `User`
- `subject_state` -> `Subject`
- `exam_state` -> `Exam`
- `attempt_state` -> `Attempt`
- `answer_state` -> `Answer`
- `result_state` -> `Result`
- `proctoringEventState` -> `ProctoringEvent`

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
  - Tampilkan `result` dari backend (`score`, `riskLevel`, status).

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
- Pilih jawaban langsung update `answersByQuestionId` lokal.
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
- Simpan `serverOffsetMs` di `examSessionState`.
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
   - Flush `pendingAnswerQueue`.
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
  - Props: `question`, `questionIndex`, `totalQuestion`.
- `OptionItem`
  - Props: `option`, `selected`, `multiSelect`, `onTap`.
- `TimerWidget`
  - Props: `remainingSeconds`, `isWarning`.
- `ProgressBar`
  - Props: `current`, `total`, `value`.
- `BottomActionBar`
  - Props: `primaryAction`, `secondaryAction`, `sticky`.
- `ConnectionChip`
  - Props: `isOnline`, `syncStatus`.
- `WarningBanner`
  - Props: `type`, `message`, `isVisible`.

## 8. Interaction Flow (Contoh Jawaban)

1. User tap opsi jawaban.
2. `examSessionState` lokal update instan.
3. Debounce timer mulai.
4. Debounce selesai -> `saveAnswer()` dipanggil.
5. Jika sukses -> tandai synced.
6. Jika gagal -> simpan ke `outboxQueue`, status pending, retry background.
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
- Semua `proctoring` event masuk queue jika gagal.
- Retry exponential backoff + jitter.
- Hard cap retry per item, sisanya tetap disimpan sampai network stabil.
- Prioritas flush: `answer` -> `proctoring` -> `submit` pre-check flush.

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

- Implement `outboxQueue` lokal persisten.
- `saveAnswer` gagal -> queue dengan dedup per `attemptId + questionId` (latest payload wins).
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
   - restore `examSessionState`,
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
- Tidak ada penyimpanan `correctAnswer` di client.
- Tidak ada crash signifikan pada Android low-end.
- Semua endpoint terintegrasi sesuai kontrak backend.
- Proctoring event terkirim dengan retry saat jaringan buruk.
- Timer akurat dan tidak reset saat rebuild/background-resume.
- Navigation flow siswa/admin konsisten dan tidak leak state antar screen.
- UX tetap responsif pada kondisi RAM kecil dan koneksi tidak stabil.

## 20. Missing Flow Completion (Implementation Addendum)

### 20.1 Contract Clarification (Agar Tidak Ambigu)
- Source of truth kontrak API adalah OpenAPI backend (`src/docs/openapi.ts`) + DTO backend.
- JSON field API saat ini menggunakan **camelCase** (contoh: `attemptId`, `riskLevel`, `attemptLimit`).
- Nilai enum tertentu tetap **snake_case** sesuai backend (contoh: `in_progress`, `high_risk`, `app_background`).
- Nama kolom DB (`snake_case`) tidak boleh dipakai sebagai acuan payload frontend.

### 20.2 Attempt Lifecycle State Transition (Start -> In Progress -> Submit -> Retry)
State frontend direpresentasikan oleh kombinasi:
- `attempt.status` (`in_progress`, `submitted`, `expired`)
- `submitState` (`idle`, `submitting`, `failed`, `success`)
- `syncStatus` (`synced`, `pending`, `retrying`)

| Current State | Event | Guard/Condition | Next State | Frontend Action |
|---|---|---|---|---|
| `idle` | User tap `Start Attempt` | exam+subject valid | `starting_attempt` (`isLoading=true`) | call `POST /attempts/start` |
| `starting_attempt` | `startAttempt` success | response `attempt.status=in_progress` | `in_progress + synced` | set `attempt`, `questions`, start timer/runtime service, persist session |
| `starting_attempt` | `startAttempt` success (active attempt existing) | backend return active attempt | `in_progress + synced` | treat as resume (bukan attempt baru) |
| `starting_attempt` | `startAttempt` fail | 4xx/5xx/network | `idle + submitState.failed` | tampilkan `errorMessage`, allow retry |
| `in_progress + synced/pending/retrying` | User pilih jawaban | attempt aktif | `in_progress + pending` | update `answersByQuestionId`, enqueue answer, debounce flush |
| `in_progress + pending/retrying` | flush sukses | queue due items sukses | `in_progress + synced` | mark success, clear error sync |
| `in_progress + pending/retrying` | flush gagal sementara | retry masih tersedia | `in_progress + retrying` | mark failure (scheduled), update retry schedule |
| `in_progress + retrying` | item drop karena retry limit | `retry_count > maxRetryLimit` | `in_progress + pending` | show dropped message (jawab ulang / retry submit) |
| `in_progress + *` | User tap submit | `submitState != submitting` | `submitting` | flush queue -> enqueue submit -> flush queue |
| `submitting` | submit success | `POST /attempts/:id/submit` 200 | `submitted + submitState.success` | set `latestResult`, stop runtime service, clear queue by attempt, route `/result` |
| `submitting` | submit timeout/network fail | recoverable error | `in_progress + submitState.failed` | blocking retry modal tetap tampil |
| `submitState.failed` | User tap `Retry Submit` | attempt masih aktif | `submitting` | ulangi alur submit idempotent |
| `in_progress + *` | timer mencapai 0 | remaining seconds <= 0 | `submitting` | lock answer interaction + auto submit |
| `in_progress + *` | recover active attempt | backend status bukan `in_progress` | `terminated_session` | clear local session, route normal flow |
| any | unauthorized | 401/403 endpoint protected | `unauthenticated` | clear auth + redirect login |

### 20.3 Reconnect Scenario (Deterministik)
1. Saat request gagal koneksi, set `connectionState=offline` dan `syncStatus=retrying`.
2. Semua aksi answer/proctoring tetap disimpan lokal ke outbox.
3. Trigger flush saat:
   - user submit,
   - debounce answer selesai,
   - app resume,
   - periodic/manual retry event.
4. Begitu request sukses kembali:
   - `connectionState=online`,
   - item queue dihapus (`markSuccess`),
   - `syncStatus` kembali `synced` jika tidak ada due item gagal.
5. Jika sebagian item gagal dan sebagian sukses, UI harus tetap menunjukkan state terbaru (`pending/retrying`), bukan langsung `synced`.

### 20.4 App Crash Recovery Flow
1. App start: restore `exam_session_state_v1` dari local preference.
2. Jika ada `attempt.status=in_progress`:
   - start runtime services (timer, lifecycle, idle, noise),
   - call `GET /attempts/:id` untuk validasi server,
   - merge jawaban server ke `answersByQuestionId`,
   - flush outbox yang masih due.
3. Jika backend mengembalikan status `submitted/expired`:
   - clear local session,
   - arahkan user ke `/result` (jika result tersedia) atau `/exam`.
4. Jika restore payload korup/invalid JSON:
   - hapus key lokal,
   - fallback ke state kosong, tanpa crash UI.

### 20.5 Multi-Device Behavior (Backend-Driven)
- Rule backend: satu active attempt untuk kombinasi `user + exam + subject`.
- Jika Device B start exam saat Device A masih `in_progress`, backend boleh return active attempt yang sama.
- Save answer bersifat upsert (latest write wins per `attemptId + questionId`).
- Submit bersifat idempotent:
  - submit pertama membuat result,
  - submit berikutnya return result yang sama.
- Frontend tidak menentukan device winner; frontend hanya menampilkan result final dari backend.

## 21. UI State Specification (Very Detail)

### 21.1 LoginScreen
| State Type | Trigger | UI Behavior | State Update | Retry/User Action |
|---|---|---|---|---|
| Loading | `auth.status=checking` atau `isLoading=true` | Disable tombol login, tampil spinner di tombol | `AuthState.isLoading=true` | tunggu request selesai |
| Empty | form awal, input kosong | render form normal tanpa error | `errorMessage=null` | user isi username/password |
| Error | login 401/400/network | tampil error text + snackbar | `status=unauthenticated`, `errorMessage` terisi | user koreksi input lalu login ulang |
| Success | login 200 | route by role (`/admin/dashboard` atau `/exam`) | `status=authenticated`, token tersimpan | tidak ada aksi tambahan |
| Edge Case | token ada tapi profile refresh gagal | fallback ke unauthenticated aman | clear secure session | user login ulang |

### 21.2 ExamListScreen
| State Type | Trigger | UI Behavior | State Update | Retry/User Action |
|---|---|---|---|---|
| Loading | `examListProvider` loading | skeleton/progress list | AsyncValue loading | wait |
| Empty | API success tapi list kosong | card text "Belum ada ujian tersedia" | AsyncValue data empty | CTA refresh/back |
| Error | fetch exam gagal | error card + tombol `Muat Ulang` | AsyncValue error | `ref.refresh(examListProvider)` |
| Success | data tersedia | render card exam + CTA `Lihat & Mulai` | AsyncValue data | ke `ExamDetailStartScreen` |
| Edge Case | user punya active attempt | route guard langsung ke `/exam/session` | baca `examSessionProvider.hasActiveAttempt` | resume exam, bukan list |

### 21.3 ExamDetailStartScreen
| State Type | Trigger | UI Behavior | State Update | Retry/User Action |
|---|---|---|---|---|
| Loading | load exam + subject + startAttempt | spinner pada list/CTA start | `isLoading=true` saat start | wait |
| Empty | subject kosong | card "Subject kosong" | no selected subject | admin perlu buat subject |
| Error | start attempt fail (attempt limit/time window) | tampil error text/snackbar | `submitState=failed`, `errorMessage` terisi | user retry start atau kembali |
| Success | start attempt sukses | route ke `/exam/session` | set attempt/questions/session persist | lanjut ujian |
| Edge Case | exam id invalid / exam tidak ditemukan | tampil card fallback + disable start | exam null | user kembali ke list exam |

### 21.4 ExamScreen
| State Type | Trigger | UI Behavior | State Update | Retry/User Action |
|---|---|---|---|---|
| Loading | submit in progress / restore active session | disable submit, spinner submit | `submitState=submitting`, `isLoading=true` | tunggu hasil |
| Empty | tidak ada active attempt | tampil fallback "Tidak ada sesi ujian aktif" | `hasActiveAttempt=false` | CTA kembali ke exam list |
| Error | submit gagal / recover gagal / queue dropped | show blocking retry modal (submit) atau warning/banner | `submitState=failed` atau `errorMessage` | `Retry Submit`, answer ulang untuk item dropped |
| Success | answer tersimpan + submit sukses | update progress, sync chip, route result saat submit success | `syncStatus=synced`, `submitState=success` | lanjut navigasi otomatis |
| Edge Case | group question malformed options | tampil fallback "Opsi tidak tersedia" untuk sub-soal invalid | answer map tetap aman | user lanjut soal lain / retry setelah data valid |
| Edge Case | timer habis | lock interaksi jawaban + auto submit | warning + `submitState=submitting` | retry submit jika gagal |
| Edge Case | offline saat exam | chip `Offline | retrying`, UI tetap bisa jawab | queue bertambah | auto flush saat reconnect |

### 21.5 ResultScreen
| State Type | Trigger | UI Behavior | State Update | Retry/User Action |
|---|---|---|---|---|
| Loading | fetch result provider | progress indicator | AsyncValue loading | wait |
| Empty | data result kosong | card "Kamu belum mengerjakan ujian" | AsyncValue data empty | kembali ke daftar/dashboard |
| Error | fetch result gagal | error card + tombol kembali | AsyncValue error | refresh results provider |
| Success | result tersedia | render latest result + historical list | latestResult + result list | user review nilai |
| Edge Case | `latestResult` ada tapi fetch list gagal | tetap tampil latest result lokal | local session tidak hilang | user refresh list tanpa hilang result terbaru |

### 21.6 Admin Screens Matrix
| Screen | Loading | Empty | Error | Success | Edge Case |
|---|---|---|---|---|---|
| `AdminDashboardScreen` | minimal (static menu) | n/a | n/a | semua menu tampil | role bukan admin harus di-redirect guard |
| `AdminSubjectManagementScreen` | spinner saat list/load action create | card "Subject kosong" | error card saat load gagal | list subject + quick create | setelah create sukses wajib invalidate `subjectListProvider` |
| `AdminSubjectEditScreen` | spinner saat load/update/delete | card "Subject tidak ditemukan" | snackbar error update/delete | simpan/hapus sukses lalu route list subject | disable tombol saat `isUpdating`/`isDeleting` |
| `AdminQuestionManagementScreen` | spinner load subject/questions/reorder | card "Pertanyaan kosong" | error card + snackbar aksi gagal | list pertanyaan + reorder + quick create | reorder fail harus rollback list dari refresh server |
| `AdminQuestionEditScreen` | spinner load/update/delete | card "Pertanyaan tidak ditemukan" | snackbar error update/delete | simpan/hapus sukses + route management | validasi 4 opsi unik + 1 correct answer wajib |
| `AdminStudentAccountManagementScreen` | spinner list/create/delete | card "Belum ada akun siswa" | snackbar error API | create/delete akun sukses + refetch | disable delete saat id sama sedang diproses |
| `AdminResultMonitoringScreen` | spinner fetch result | card "Belum ada result" | error card result | list result admin | nilai risk/score dari backend tanpa kalkulasi frontend |

## 22. Edge Cases & Failure Scenarios (UI + State + Retry)

| Scenario | UI Behavior | State Update | Retry Logic |
|---|---|---|---|
| Network lost saat answer save | non-blocking warning + connection chip offline | enqueue answer, `syncStatus=pending/retrying` | auto retry via queue backoff; user tetap lanjut jawab |
| Network lost saat submit | blocking modal `Submit Gagal` | `submitState=failed`, attempt tetap `in_progress` | tombol `Retry Submit` memanggil submit idempotent endpoint sama |
| Submit timeout | sama seperti submit fail, jangan clear session | `submitState=failed`, queue submit tetap ada/scheduled | retry sampai backend response diterima |
| Duplicate submit tap | tombol submit disable saat `submitting` | cegah duplicate UI action | jika request ganda tetap aman karena backend idempotent |
| Partial answer sync (sebagian sukses) | chip menunjukkan `pending/retrying`; tidak klaim synced penuh | item sukses dihapus, item gagal tetap di queue | retry item gagal sesuai due time |
| Server delay tinggi (> timeout client) | tampil message koneksi lambat, tidak freeze UI | request dianggap gagal timeout | retry otomatis/manual tergantung action (answer queue / submit modal) |
| Invalid payload dari backend | fallback screen/card + pesan data tidak valid | jangan mutate state dengan data rusak | user bisa refresh; jika fatal clear sesi korup |
| `Attempt is not active` saat save answer | tampil warning bahwa sesi berakhir | set submit failed atau clear active session setelah verifikasi | arahkan ke result/list sesuai status backend terbaru |
| `Attempt time already ended` saat save answer | lock input jawaban, tampil warning timeout | force `submitAttempt()` | retry submit idempotent hingga sukses |
| 401/403 di tengah exam | tampil "sesi berakhir", stop exam interaction | clear auth + clear sensitive exam state | route `/login`, setelah login jalankan recover attempt |
| Queue item dropped setelah retry limit | tampil pesan spesifik per item type | item dihapus dari queue, `syncStatus=pending` | answer/proctoring: user lanjut; submit: wajib retry submit manual |
| Proctoring endpoint return `ignored` | non-blocking info di UI (opsional) | event dianggap diterima tapi tak berdampak frontend | tidak perlu retry item yang sudah accepted/ignored valid |

## 23. Data Contract Awareness (Frontend Perspective)

### 23.1 Naming Rules
- Gunakan nama field persis API contract saat ini (camelCase).
- Jangan mengonversi manual ke snake_case.
- Enum value string wajib mengikuti backend persis.

### 23.2 Entity: `Exam`
| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `string(uuid)` | yes | primary id exam |
| `title` | `string` | yes | judul exam |
| `isPublished` | `boolean` | yes | akses exam |
| `startTime` | `string(date-time)` | yes | window mulai |
| `endTime` | `string(date-time)` | yes | window selesai |
| `videoProvider` | `string \| null` | optional | bisa null |
| `videoRoomId` | `string \| null` | optional | bisa null |

### 23.3 Entity: `Attempt`
| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `string(uuid)` | yes | id attempt |
| `userId` | `string(uuid)` | yes | pemilik attempt |
| `examId` | `string(uuid)` | yes | relasi exam |
| `subjectId` | `string(uuid)` | yes | relasi subject |
| `attemptNo` | `integer` | yes | nomor attempt |
| `startTime` | `string(date-time)` | yes | start server |
| `endTime` | `string(date-time) \| null` | optional | terisi setelah submit/expired |
| `status` | `string` | yes | enum: `in_progress`, `submitted`, `expired` |

### 23.4 Entity: `Question` (Siswa)
| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `string(uuid)` | yes | id question |
| `subjectId` | `string(uuid)` | yes | relasi subject |
| `type` | `string` | yes | enum: `single`, `multi`, `group` |
| `text` | `string` | yes | isi soal |
| `options` | `object \| array \| null` | yes | struktur dinamis sesuai type |
| `weight` | `number` | yes | bobot soal |

Aturan:
- `correctAnswer` **tidak boleh dipakai** pada flow siswa.
- Untuk flow admin, `correctAnswer` ada dan wajib valid terhadap opsi.

### 23.5 Entity: `Answer`
Request `POST /answers`:
| Field | Type | Required | Notes |
|---|---|---|---|
| `attemptId` | `string(uuid)` | yes | id attempt aktif |
| `questionId` | `string(uuid)` | yes | id soal |
| `answer` | `any json` | yes | string/list/map sesuai type soal |

Response `AnswerResponse`:
| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `string(uuid)` | yes | id answer row |
| `attemptId` | `string(uuid)` | yes | relasi attempt |
| `questionId` | `string(uuid)` | yes | relasi question |
| `answer` | `any json` | yes | payload tersimpan |
| `isCorrect` | `boolean \| null` | optional | bukan sumber UI penilaian siswa |
| `createdAt` | `string(date-time)` | yes | server timestamp |
| `updatedAt` | `string(date-time)` | yes | server timestamp |

### 23.6 Entity: `Result`
| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `string(uuid)` | yes | id result |
| `attemptId` | `string(uuid)` | yes | relasi attempt |
| `score` | `number` | yes | nilai final |
| `correct` | `integer` | yes | jumlah benar |
| `wrong` | `integer` | yes | jumlah salah |
| `duration` | `integer` | yes | detik |
| `cheatScore` | `integer` | yes | score anti-cheat dari backend |
| `riskLevel` | `string` | yes | enum: `safe`, `suspicious`, `high_risk` |
| `examTitle` | `string \| null` | optional | untuk display |
| `subjectName` | `string \| null` | optional | untuk display |
| `username` | `string \| null` | optional | admin only |

## 24. Component Behavior Rules (Reusable)

| Component | Interaction Rules | Disabled Conditions | Loading Handling | Error Fallback |
|---|---|---|---|---|
| `AppButton` | single tap trigger `onPressed` | disable jika `loading=true` atau `disabled=true` atau `onPressed=null` | spinner inline ganti label | tampilkan label default; error tampil di parent snackbar/banner |
| `AppCard` | container informatif + optional child | tidak ada state disable internal | n/a | jika `subtitle/status` null, card tetap render aman |
| `QuestionCard` | tampil metadata nomor + text soal | n/a | n/a | jika text kosong, tampil placeholder text agar layout tidak collapse |
| `OptionItem` | tap toggle selected; mode single/multi beda icon | disable via parent (jangan kirim `onTap` jika locked) | n/a | jika option invalid, tampil text fallback `"Opsi tidak tersedia"` |
| `TimerWidget` | update tiap detik dari session state | n/a | n/a | jika value invalid/negatif, clamp ke `00:00:00` di level state |
| `ProgressBar` | read-only indikator progress | n/a | n/a | clamp `value` ke `0..1` agar tidak overflow |
| `BottomActionBar` | sticky action bar di bawah untuk CTA utama | disable per tombol child | loading dihandle oleh `BottomActionBarButton` | jika secondary action null, render primary full width |
| `BottomActionBarButton` | wrapper `AppButton` | mengikuti `disabled/loading` props | mengikuti spinner `AppButton` | error ditangani parent flow |
| `ConnectionChip` | read-only status online/offline + sync | n/a | n/a | jika `syncStatus` unknown, tetap tampil string mentah |
| `WarningBanner` | tampil pesan warning/info/danger non-blocking | hidden saat `isVisible=false` | n/a | jika message kosong, parent wajib tidak render banner |
| `AppSnackBar` | global transient feedback | n/a | n/a | jika `ScaffoldMessenger` null, silent fail tanpa crash |

## 25. State Management Detailing (Riverpod)

### 25.1 Provider Structure (Current + Mandatory Usage)
| Provider | Type | Scope | Persisted | Depends On | Responsibility |
|---|---|---|---|---|---|
| `apiClientProvider` | `Provider<Dio>` | global app | no | `secureStorageProvider` | auth header, timeout, intercept 401 |
| `authProvider` | `NotifierProvider<AuthNotifier, AuthState>` | global app | yes (token+user di secure storage) | `authServiceProvider` | login/logout/restore auth session |
| `examServiceProvider` | `Provider<ExamService>` | global feature | no | `apiClientProvider` | HTTP exam domain |
| `examListProvider` | `FutureProvider<List<ApiExam>>` | screen-scoped read | no | `examServiceProvider` | fetch list exam |
| `subjectListProvider` | `FutureProvider<List<ApiSubject>>` | screen-scoped read | no | `examServiceProvider` | fetch list subject |
| `myResultsProvider` | `FutureProvider<List<ResultResponse>>` | screen-scoped read | no | `examServiceProvider` | fetch result siswa |
| `adminResultsProvider` | `FutureProvider<List<ResultResponse>>` | screen-scoped read | no | `examServiceProvider` | fetch result admin |
| `examSessionProvider` | `NotifierProvider<ExamSessionNotifier, ExamSessionState>` | global selama app hidup | yes (`exam_session_state_v1`, outbox sqlite) | `examServiceProvider`, `outboxQueueProvider`, `appPreferencesProvider` | runtime exam, timer, queue, recovery |
| `adminSubjectActionProvider` | `NotifierProvider` | scoped admin screen | no | `examServiceProvider` | create/update/delete subject |
| `questionListBySubjectProvider` | `FutureProvider.family` | scoped per subject | no | `examServiceProvider` | list question by subject |
| `adminQuestionActionProvider` | `NotifierProvider` | scoped admin screen | no | `examServiceProvider` | create/update/delete/reorder question |
| `studentAccountsProvider` | `FutureProvider` | scoped admin screen | no | `studentAccountServiceProvider` | list akun siswa |

### 25.2 State Lifecycle Rules
- `AuthState`:
  - init: `checking` -> restore token/user.
  - success: `authenticated`.
  - fail/expired: `unauthenticated`.
- `ExamSessionState`:
  - init build: restore local -> refresh queue -> recover attempt (jika ada active attempt).
  - active runtime: jawab soal, timer tick, proctoring enqueue, flush outbox.
  - terminal: submit success atau clearSession.
- `FutureProvider` screen data:
  - refresh manual via `ref.refresh(...)`.
  - invalidate wajib setelah aksi admin mutate data.

### 25.3 Global vs Scoped vs Persisted
| Category | Item |
|---|---|
| Global state | `authProvider`, `examSessionProvider`, router guard dependencies |
| Scoped state | form controller local screen, dialog state, selected filters/tab |
| Persisted state | secure token/user, `exam_session_state_v1`, sqlite `outbox_items` |

### 25.4 Dependency Rules
- `authProvider` berubah -> router redirect dievaluasi ulang.
- `examSessionProvider.attempt.status` berubah -> redirect siswa dievaluasi ulang.
- Mutation admin (`create/update/delete/reorder`) **harus** invalidate provider list terkait.
- Logout harus membersihkan auth session; untuk mencegah leak antar user, clear exam session saat logout jika ada active session.

## 26. Offline & Queue Deep Spec

### 26.1 Queue Item Structure (`outbox_items`)
| Field | Type | Keterangan |
|---|---|---|
| `id` | `string` | unique id lokal |
| `type` | `answer \| proctoring \| submit` | tipe item |
| `dedup_key` | `string \| null` | kunci dedup tipe tertentu |
| `payload_json` | `string(json)` | payload API |
| `retry_count` | `int` | jumlah retry saat ini |
| `next_retry_at_epoch_ms` | `int` | kapan item boleh diproses lagi |
| `created_at_epoch_ms` | `int` | waktu enqueue |

### 26.2 Deduplication Rules
- `answer`: dedup by `attemptId::questionId`, **latest payload wins**.
- `submit`: dedup by `attemptId`, hanya satu pending submit per attempt.
- `proctoring`: tidak dedup (event stream), semua event disimpan berurutan.

### 26.3 Retry Strategy (Detail)
- `maxRetryLimit = 6`.
- Saat fail:
  - `retry_count += 1`,
  - jika `retry_count > 6` -> item dropped.
- Backoff formula:
  - `base = 600ms`,
  - `raw = base * 2^(retryCount-1)`,
  - `jitter = random(0..299ms)`,
  - `delay = min(60000ms, raw + jitter)`.
- Action hasil `markFailure`:
  - `scheduled` -> `syncStatus=retrying`.
  - `missing` -> `syncStatus=pending` (item sudah tidak ditemukan).
  - `dropped` -> tampil pesan dropped per tipe item.

### 26.4 Priority Handling
Prioritas flush item due:
1. `answer`
2. `proctoring`
3. `submit`

Aturan:
- Submit selalu didahului flush answer/proctoring due agar data jawaban terbaru tersinkron sebelum final submit.
- Flush dijaga single-flight (`_isFlushing`) untuk mencegah race request paralel.

### 26.5 Failure Recovery Flow
1. User answer/proctoring saat offline -> enqueue + persist.
2. App restart -> queue tetap ada (sqlite), state queue di-refresh ke UI.
3. Saat ada kesempatan flush:
   - due item diproses sesuai prioritas.
   - sukses: delete item.
   - gagal recoverable: jadwalkan retry.
   - dropped:
     - answer: minta user jawab ulang.
     - proctoring: info non-blocking.
     - submit: blocking retry submit.
4. Setelah semua due sukses -> `syncStatus=synced`.

## 27. Navigation Guard Edge Cases

| Case | Route Decision | State Decision |
|---|---|---|
| token expired mid-exam (401/403) | paksa ke `/login` | clear auth session; clear exam session sensitif |
| user siswa akses route admin | redirect ke `/exam` | tidak ada akses admin state |
| user admin akses route siswa | redirect ke `/admin/dashboard` | tetap di flow admin |
| attempt masih `in_progress` | redirect paksa ke `/exam/session` | prioritas resume exam dari route lain |
| attempt sudah submitted saat buka `/exam/session` | redirect ke `/result` atau `/exam` jika result belum ada | clear active session |
| app force close lalu reopen | jika local active session valid -> `/exam/session` | jalankan restore + recover + flush |
| direct hit `/result` tanpa auth | redirect `/login` | jangan render result data |
| logout saat active attempt | redirect `/login` | bersihkan auth + queue/session lokal |

## 28. Performance Rules (Low-End Device)

### 28.1 Runtime Constraints
- Target device baseline: Android RAM 2GB, CPU kelas entry-mid.
- `ExamScreen` harus tetap responsif saat timer tick 1 detik.
- Hindari full-screen jank saat queue flush/background sync.

### 28.2 Rebuild & Rendering Rules
- Gunakan `select`/granular provider agar rebuild lokal (timer, chip, progress) tidak merender ulang subtree berat.
- Pertanyaan dirender incremental (`current + nearby`), hindari render semua konten berat sekaligus.
- Komponen statis wajib `const` bila memungkinkan.
- Hindari setState global untuk state yang sudah ada di provider.

### 28.3 Memory Usage Strategy
- Batasi `proctoringBuffer` maksimum 100 event di memory.
- Jangan simpan media mentah (audio/video/screenshot) di client.
- Queue lokal menyimpan payload ringkas JSON saja.
- Buang state runtime service saat submit sukses/clear session.

### 28.4 JSON Parsing Strategy
- Parsing payload kecil langsung di isolate UI masih boleh.
- Parsing payload besar (misal >150KB atau list besar admin) gunakan isolate (`compute`) untuk menghindari frame drop.
- Selalu validasi tipe field dari response sebelum cast.

### 28.5 Anti-Patterns to Avoid
- Parsing JSON di dalam `build()`.
- Menjalankan request network berulang di `build()` tanpa guard.
- Menampilkan dialog berulang dari listener yang tidak memfilter perubahan state.
- Logging verbose pada release build.
- Menyimpan data derivatif backend sensitif (`correctAnswer`, score kalkulasi) di state siswa.

## 29. QA Checklist Expansion (Testable)

### 29.1 Auth & Routing
[ ] Login sukses admin route ke `/admin/dashboard`.
[ ] Login sukses siswa route ke `/exam` atau `/exam/session` jika ada active attempt.
[ ] Login gagal 401 tampil error dan tidak navigate.
[ ] Tanpa token, akses route protected selalu redirect `/login`.
[ ] Siswa tidak bisa akses route admin.
[ ] Admin tidak bisa masuk flow siswa.

### 29.2 Attempt Lifecycle
[ ] Start attempt sukses set `attempt.status=in_progress`.
[ ] Start attempt saat active attempt existing tidak membuat attempt baru.
[ ] Attempt limit reached tampil error backend dan state tetap aman.
[ ] Jawab soal update lokal instan sebelum network selesai.
[ ] Debounce save berjalan (tidak spam request tiap tap cepat).
[ ] Submit hanya bisa 1 request aktif (`submitting` lock).
[ ] Submit sukses memindahkan route ke `/result` dan clear runtime service.
[ ] Retry submit dari modal berhasil saat jaringan kembali.

### 29.3 UI State Per Screen
[ ] `LoginScreen` punya loading/empty/error/success/edge state sesuai spec.
[ ] `ExamListScreen` punya loading/empty/error/success/edge state sesuai spec.
[ ] `ExamDetailStartScreen` punya loading/empty/error/success/edge state sesuai spec.
[ ] `ExamScreen` punya loading/empty/error/success/edge state sesuai spec.
[ ] `ResultScreen` punya loading/empty/error/success/edge state sesuai spec.
[ ] Semua Admin screens punya loading/empty/error/success/edge state sesuai spec.

### 29.4 Offline & Queue
[ ] Offline saat answer: item masuk queue dan UI tetap bisa lanjut jawab.
[ ] Online kembali: queue answer flush otomatis.
[ ] Queue dedup answer bekerja (`attemptId::questionId` latest wins).
[ ] Queue submit dedup per `attemptId`.
[ ] Proctoring queue tidak dedup.
[ ] Backoff bertambah eksponensial dan capped 60 detik.
[ ] Item dropped menampilkan pesan sesuai tipe item.
[ ] Submit dropped memunculkan jalur retry yang jelas.

### 29.5 Failure Scenarios
[ ] Submit timeout memunculkan modal retry blocking.
[ ] Duplicate submit tap tidak mengirim request paralel.
[ ] Partial sync menampilkan status `pending/retrying` sampai benar-benar synced.
[ ] Invalid payload backend tidak menyebabkan crash UI.
[ ] 401/403 saat exam menyebabkan redirect login dan pembersihan state sensitif.
[ ] `Attempt is not active` ditangani sebagai sesi berakhir, bukan crash.

### 29.6 Session Recovery
[ ] Force close app saat exam, reopen kembali ke sesi aktif bila backend masih `in_progress`.
[ ] Recover session merge jawaban server + local queue.
[ ] Jika backend bilang submitted/expired, session lokal dibersihkan.
[ ] Session JSON korup tidak menyebabkan crash (fallback clear key).

### 29.7 Data Contract Compliance
[ ] Request/response field mengikuti nama backend persis (camelCase + enum values).
[ ] Tidak ada penggunaan `correctAnswer` di flow siswa.
[ ] `riskLevel` hanya dari backend response, bukan kalkulasi frontend.
[ ] Group answer payload format konsisten (`Map<subQuestionId, value>`).

### 29.8 Performance & Stability
[ ] Timer tetap akurat saat app background-resume.
[ ] Tidak ada freeze signifikan pada device low-end saat queue flush.
[ ] Memory tetap stabil pada sesi exam panjang.
[ ] Rebuild subtree berat tidak terjadi tiap detik.
[ ] Release build tanpa verbose log berlebih.

## 30. API Error Contract Standardization

### 30.1 Standard Error JSON (Frontend Contract)
Frontend harus menerima format minimal berikut untuk semua error API:

```json
{
  "message": "string",
  "details": {}
}
```

Format error yang direkomendasikan untuk production (opsional field tambahan):

```json
{
  "message": "Attempt is not active",
  "code": "ATTEMPT_NOT_ACTIVE",
  "details": {
    "attemptId": "uuid"
  },
  "requestId": "req-8f0c2f1a",
  "timestamp": "2026-04-18T10:20:30.000Z"
}
```

Aturan parsing frontend:
- Field wajib dipakai: `message`.
- Field opsional: `code`, `details`, `requestId`, `timestamp`.
- Jika payload error tidak valid JSON, gunakan fallback message berdasarkan HTTP status.

### 30.2 HTTP Status -> UI Behavior Mapping
| HTTP Status | Retry Class | UI Behavior | State Update | User Action |
|---|---|---|---|---|
| `400` | non-retryable (default) | tampil error spesifik validasi/domain | set `errorMessage`, stop loading | perbaiki aksi/input, retry manual |
| `401` | non-retryable | tampil sesi berakhir | clear auth, clear sensitive session | paksa login ulang |
| `403` | non-retryable | tampil akses ditolak | tetap di screen aman / redirect by role | kembali ke route valid |
| `404` | non-retryable | tampil data tidak ditemukan | invalidate view model terkait | refresh data / kembali |
| `409` | non-retryable | tampil konflik data | pertahankan state terakhir valid | retry setelah refresh |
| `422` | non-retryable | tampil validasi gagal | mark field/screen error | perbaiki input |
| `429` | retryable | tampil "server sibuk" non-blocking | set retrying state | auto retry dengan backoff |
| `500` | retryable | tampil error server sementara | queue/retry jika endpoint critical | auto/manual retry |
| `502`/`503`/`504` | retryable | tampil gangguan layanan | `syncStatus=retrying` untuk flow exam | auto retry |
| timeout/network unreachable | retryable | tampil koneksi bermasalah | `connectionState=offline` | auto retry saat reconnect |

### 30.3 Retryable vs Non-Retryable Rules
Klasifikasi wajib:
- Retryable:
  - network error (`connectionTimeout`, `receiveTimeout`, `connectionError`)
  - HTTP `429`, `500`, `502`, `503`, `504`
- Non-retryable:
  - HTTP `400`, `401`, `403`, `404`, `409`, `422`
- Endpoint override:
  - `POST /attempts/:id/submit`: meskipun error retryable, UI wajib blocking retry sampai backend memberi hasil final.

## 31. Network Policy

### 31.1 Timeout Policy per Endpoint Type
| Endpoint Type | Connect Timeout | Send Timeout | Receive Timeout | Notes |
|---|---|---|---|---|
| Auth (`/auth/login`, `/users/me`) | 8s | 8s | 12s | login harus cepat fail-fast |
| Read List/Detail (`/exams`, `/subjects`, `/results/*`) | 10s | 10s | 15s | aman untuk payload list |
| Answer Save (`/answers`) | 5s | 5s | 8s | cepat, lanjut via queue jika gagal |
| Proctoring (`/proctoring/events`) | 5s | 5s | 8s | selalu queue-first safe |
| Start Attempt (`/attempts/start`) | 8s | 8s | 15s | blocking action |
| Submit (`/attempts/:id/submit`) | 8s | 8s | 40s | beri waktu scoring server |

### 31.2 Request Failure Definition
Satu request dianggap gagal jika salah satu kondisi terjadi:
- tidak menerima response 2xx dalam batas timeout endpoint.
- menerima status non-2xx.
- response 2xx tapi payload gagal parse ke contract model.
- request dibatalkan karena app dispose sebelum response tiba (treated as canceled, bukan success).

### 31.3 Retry Classification Rules
| Flow | Auto Retry | Max Immediate Retry | Fallback |
|---|---|---|---|
| Login | tidak | 0 | user retry manual |
| Start Attempt | tidak | 0 | user retry manual |
| Save Answer | ya (via outbox queue) | mengikuti queue policy | latest answer tetap lokal |
| Proctoring | ya (via outbox queue) | mengikuti queue policy | event tetap lokal |
| Submit | ya (blocking modal + queue submit) | tanpa batas UI sampai final respons | retry submit idempotent |
| Read-only fetch list | tidak | 0 | tombol refresh manual |

## 32. UI Interaction Guard

### 32.1 Debounce / Throttle Rules
| Interaction | Guard Type | Value | Implementation Rule |
|---|---|---|---|
| Tap jawaban | optimistic update + debounce sync | debounce 700ms per attempt | update UI instan, network flush tertunda |
| Tap jawaban berulang sangat cepat | throttle input | 80ms | abaikan tap duplikat dalam jendela throttle |
| Next/Previous question | throttle navigation | 200ms | cegah double navigate antar soal |
| Tap `Start Attempt` | action lock | selama `isLoading=true` | tombol disabled |
| Tap `Submit` | mutex + debounce | mutex by `submitState=submitting`, debounce 800ms | hanya 1 submit flow aktif |
| Tap `Retry Submit` | mutex | selama submit aktif | abaikan tap berulang |

### 32.2 Duplicate Action Prevention (Mandatory)
- Semua CTA utama (`Login`, `Start`, `Submit`, `Retry Submit`, `Save Admin`) wajib disable saat loading.
- Route push untuk aksi tunggal harus idempotent di UI: jika route target sudah aktif, jangan push ulang.
- Listener yang memunculkan dialog wajib cek transition state (`prev != next`) agar dialog tidak muncul berulang.

## 33. Token & Auth Strategy

### 33.1 Token Storage
| Data | Storage | Encryption | TTL Handling |
|---|---|---|---|
| `auth_token` | `flutter_secure_storage` | platform keystore/keychain | valid sampai expiry backend |
| cached `auth_user` | `flutter_secure_storage` | platform keystore/keychain | refresh saat `/users/me` sukses |
| exam session runtime | `SharedPreferences` + sqlite | non-secret data only | dibersihkan saat session selesai/logout |

### 33.2 Token Expiration Handling
- Primary rule: backend 401 adalah indikator final token invalid/expired.
- Optional proactive check:
  - jika JWT memiliki `exp`, frontend boleh mendeteksi token hampir habis (`<=60s`) untuk trigger re-auth flow.
- Jika request protected menerima `401`:
  - clear token + user dari secure storage,
  - stop request lanjut,
  - redirect ke `/login`.

### 33.3 Optional Refresh Token Flow (Future-Ready)
Jika backend menambahkan refresh token:
- endpoint: `POST /auth/refresh`.
- refresh token disimpan di secure storage terpisah.
- refresh process harus single-flight (1 proses refresh untuk semua request paralel).
- jika refresh gagal, fallback ke logout paksa.

Jika backend belum menyediakan refresh (kondisi saat ini):
- gunakan access token only.
- 401 langsung logout paksa.

### 33.4 401 Mid-Exam Behavior
Urutan wajib:
1. Persist semua jawaban/event lokal yang belum terkirim.
2. Tampilkan pesan "Sesi berakhir, login ulang untuk melanjutkan sinkronisasi."
3. Clear auth session dan route ke `/login`.
4. Setelah login berhasil:
   - jalankan recovery attempt,
   - flush outbox queue untuk attempt yang sama jika masih aktif di backend.

## 34. Remote Config / Feature Flag

### 34.1 Remote Config Contract (Backend-Driven)
Endpoint rekomendasi: `GET /mobile/config` (auth required).

```json
{
  "configVersion": "2026.04.18.1",
  "ttlSeconds": 21600,
  "proctoring": {
    "enabled": true,
    "idleThresholdSeconds": 30,
    "noiseIntervalSeconds": 20
  },
  "queue": {
    "maxRetryLimit": 6,
    "maxBackoffMs": 60000
  },
  "features": {
    "enableNoiseProctoring": true,
    "enableIdleProctoring": true,
    "enableDeepLinkExam": false
  }
}
```

### 34.2 Config Keys (Mandatory)
| Key | Type | Default | Update Policy |
|---|---|---|---|
| `proctoring.enabled` | bool | `true` | immediate |
| `proctoring.idleThresholdSeconds` | int | `30` | apply next runtime tick |
| `proctoring.noiseIntervalSeconds` | int | `20` | apply next scheduler cycle |
| `queue.maxRetryLimit` | int | `6` | apply for new retries |
| `queue.maxBackoffMs` | int | `60000` | apply for new retries |
| `features.enableNoiseProctoring` | bool | `true` | immediate |
| `features.enableIdleProctoring` | bool | `true` | immediate |
| `features.enableDeepLinkExam` | bool | `false` | next app foreground |

### 34.3 Fetch & Cache Policy
- Fetch trigger:
  - app launch,
  - login success,
  - setiap app resume jika cache stale.
- Cache TTL:
  - gunakan `ttlSeconds` dari server.
  - jika tidak ada, default 6 jam.
- Fail-safe:
  - jika fetch gagal, gunakan cache terakhir.
  - jika cache kosong, gunakan hardcoded default aman.

## 35. Logging & Observability

### 35.1 Logging Policy (Dev vs Production)
| Category | Dev | Production |
|---|---|---|
| HTTP request/response metadata | full (method, path, status, duration) | minimal (method, path, status, duration) |
| headers/body | boleh untuk debug lokal (redacted) | dilarang log body sensitif |
| queue internals | detail (`queue_size`, `retry_count`) | aggregate + warning only |
| auth flow | status event saja | status event saja |
| fatal exception | full stack trace | full stack trace ke crash reporter |

### 35.2 Crash Reporting Strategy
- Integrasi crash reporter (contoh: Firebase Crashlytics/Sentry) wajib untuk release.
- Set breadcrumb minimal:
  - route screen,
  - attemptId (masked),
  - queue length,
  - connection status,
  - last API endpoint.
- Fatal crash saat exam harus tagged `exam_runtime=true`.

### 35.3 Queue Debug Logs (Operational)
Log event minimum:
- `queue_enqueue` (`type`, `attemptId`, `size_after`)
- `queue_flush_start` (`due_count`)
- `queue_item_success` (`item_id`, `type`)
- `queue_item_failure` (`item_id`, `type`, `retry_count`, `next_retry_at`)
- `queue_item_dropped` (`item_id`, `type`)

### 35.4 Sensitive Data Restrictions
Dilarang masuk log/analytics/crash breadcrumbs:
- token auth, password, refresh token.
- isi jawaban lengkap user (`answer` raw).
- `correctAnswer`.
- detail PII mentah (username/email/phone) tanpa masking.

## 36. Analytics Events

### 36.1 Event Catalog
| Event Name | Trigger | Required Payload |
|---|---|---|
| `auth_login_attempt` | user tap login | `session_id`, `screen`, `network_state` |
| `auth_login_success` | login sukses | `session_id`, `user_role`, `latency_ms` |
| `auth_login_failed` | login gagal | `session_id`, `http_status`, `error_code` |
| `exam_start_attempt` | user tap start exam | `session_id`, `exam_id`, `subject_id` |
| `exam_start_success` | start attempt sukses | `attemptId`, `attemptNo`, `latencyMs` |
| `exam_start_failed` | start attempt gagal | `examId`, `subjectId`, `httpStatus`, `errorCode` |
| `exam_answer_changed` | jawaban berubah lokal | `attemptId`, `questionId`, `questionType` |
| `exam_answer_sync_failed` | save answer gagal | `attemptId`, `queueSize`, `retryCount` |
| `exam_submit_attempt` | submit flow dimulai | `attemptId`, `unansweredCount` |
| `exam_submit_success` | submit sukses | `attemptId`, `durationSec`, `latencyMs` |
| `exam_submit_failed` | submit gagal | `attemptId`, `httpStatus`, `retryable` |
| `exam_reconnect` | offline -> online | `attemptId`, `offlineDurationSec`, `queueSize` |

### 36.2 Payload Examples
```json
{
  "event": "auth_login_failed",
  "timestamp": "2026-04-18T11:10:02.112Z",
  "payload": {
    "session_id": "sess-1f7f",
    "http_status": 401,
    "error_code": "INVALID_CREDENTIALS"
  }
}
```

```json
{
  "event": "exam_submit_success",
  "timestamp": "2026-04-18T11:30:45.501Z",
  "payload": {
    "attemptId": "a9c2-uuid",
    "durationSec": 3190,
    "latencyMs": 14820
  }
}
```

```json
{
  "event": "exam_reconnect",
  "timestamp": "2026-04-18T11:22:03.000Z",
  "payload": {
    "attemptId": "a9c2-uuid",
    "offlineDurationSec": 95,
    "queueSize": 14
  }
}
```

### 36.3 Analytics Data Governance
- Event tidak boleh mengandung raw answer/token/password.
- Gunakan `attemptId` sebagai identifier teknis utama.
- `username` jika dibutuhkan wajib di-hash/masked.

## 37. Security Extension (Client Side)

### 37.1 Token Security Rules
- Access token wajib di `flutter_secure_storage` (hardware-backed bila tersedia).
- Token tidak boleh disimpan di SharedPreferences/sqflite/plain file.
- Logout wajib menghapus token dan user cache secara atomik.

### 37.2 Local Storage Protection
| Data Class | Storage | Protection Rule |
|---|---|---|
| Auth secret (`token`) | secure storage | encrypted by platform |
| Exam runtime non-secret | preferences/sqlite | boleh plain, tapi tanpa secret |
| Queue payload | sqlite | dilarang menyertakan secret credential |

### 37.3 Anti-Tampering Considerations
- Build release harus:
  - `android:debuggable=false`,
  - minify + obfuscation aktif sesuai policy release.
- Root/emulator detection boleh dipakai sebagai signal proctoring tambahan, bukan blok mutlak.
- Jika integrity signal gagal, kirim event telemetry ke backend (non-blocking).

### 37.4 Replay Attack Prevention (Frontend Perspective)
- Semua call wajib via HTTPS di production (`usesCleartextTraffic=false` pada release).
- Submit tetap aman via backend idempotent transaction.
- Frontend wajib menyertakan timestamp request (`Date` header default) dan unique request id header jika backend mendukung (`X-Request-Id`).
- Frontend tidak memvalidasi anti-replay final; backend tetap pemutus.

## 38. Platform Constraints (Android)

### 38.1 Android Version Policy
| Item | Requirement |
|---|---|
| Minimum Android | API 24 (Android 7.0) |
| Target Android | mengikuti stable target SDK Flutter terbaru saat release |
| Device RAM Target | 2GB minimum operational |

### 38.2 Permission Handling
| Permission | Required | Runtime Prompt | Usage |
|---|---|---|---|
| `INTERNET` | yes | no | semua API call |
| `RECORD_AUDIO` | conditional | yes | noise proctoring |
| `POST_NOTIFICATIONS` | optional | yes (API 33+) | reminder/status notification (jika diaktifkan) |

Aturan:
- Jika `RECORD_AUDIO` ditolak:
  - exam tetap berjalan,
  - kirim signal proctoring capability disabled ke backend,
  - tampil warning transparan ke user.

### 38.3 Background Execution Limits
- App tidak boleh mengandalkan background service panjang untuk submit.
- Saat app background:
  - event `app_background` wajib diqueue,
  - flush queue dilanjutkan saat app foreground/resume.
- Timer tetap dihitung berbasis waktu server offset, bukan timer background hard-loop.

### 38.4 Battery Optimization Considerations
- Sampling noise/idle wajib low frequency sesuai remote config.
- Hindari wakelock permanen.
- Jangan meminta user disable battery optimization kecuali mode darurat dan disetujui produk.

## 39. Deep Link & Entry Point

### 39.1 Deep Link Route Spec
| Link Pattern | Target Route | Guarded By |
|---|---|---|
| `quiz://login` | `/login` | none |
| `quiz://exam/{examId}/start` | `/exam/{examId}/start` | auth + role siswa |
| `quiz://exam/session/{attemptId}` | `/exam/session` | auth + active attempt |
| `quiz://result/{attemptId}` | `/result` | auth + ownership/role |
| `quiz://admin/results` | `/admin/results` | auth + role admin |

### 39.2 External Link Open Behavior
Urutan resolusi:
1. parse deep link.
2. validasi auth.
3. validasi role.
4. validasi attempt guard.
5. route final.

Fallback:
- link invalid -> `/login` jika belum auth, `/exam` atau `/admin/dashboard` jika sudah auth.

### 39.3 Notification Entry Behavior
Payload notification minimal:
```json
{
  "type": "exam_reminder",
  "examId": "uuid",
  "attemptId": "uuid"
}
```

Rules:
- app terminated: deep link diproses setelah auth restore selesai.
- app foreground: jangan interrupt exam aktif kecuali target adalah exam session yang sama.
- jika exam aktif berbeda attemptId, tetap di attempt yang sedang berjalan.

## 40. Non-Functional Requirements (Measurable)

### 40.1 Performance & Reliability Targets
| Metric | Target | Measurement Scope |
|---|---|---|
| Cold start to first interactive frame | <= 2.5s (p95) | Android API 24, RAM 2GB |
| Warm start to interactive | <= 1.2s (p95) | device target |
| Login API latency (stable network) | <= 3s (p95) | client observed |
| Exam list fetch latency (stable network) | <= 3s (p95) | client observed |
| Answer tap -> local state update | <= 100ms (p99) | UI thread |
| Submit complete (stable network) | <= 20s (p95) | termasuk backend scoring |
| Crash-free session rate | >= 99.7% | release production |
| ANR rate | < 0.2% | release production |

### 40.2 Offline Tolerance & Data Durability
| Metric | Target |
|---|---|
| Offline exam continuation | minimal 180 menit tanpa kehilangan jawaban lokal |
| Queue persistence durability | survive app kill/restart 100% pada normal shutdown |
| Reconnect flush recovery | >= 95% item queued terkirim <= 120s setelah online kembali |

### 40.3 Memory & Resource Constraints
| Metric | Target |
|---|---|
| Peak memory during exam | <= 220MB (p95) pada device 2GB |
| Proctoring buffer size | max 100 event in-memory |
| CPU sustained usage during active exam | <= 35% rata-rata pada device target |
| Battery drain | <= 8% per 30 menit exam (tanpa video call) |

## 41. Release & Rollback Strategy (Frontend)

### 41.1 Staged Rollout Plan
| Stage | Audience | Duration | Exit Criteria |
|---|---|---|---|
| Stage 0 | internal QA | 2-3 hari | semua critical flow pass |
| Stage 1 | 5% production users | 24 jam | crash-free >= 99.7%, no P0 |
| Stage 2 | 25% users | 24-48 jam | submit failure tidak naik > 0.5% |
| Stage 3 | 50% users | 24-48 jam | queue dropped rate stabil |
| Stage 4 | 100% users | final | semua metric sehat |

### 41.2 Safe Fallback Behavior
- Semua fitur non-esensial harus punya kill switch via remote config:
  - noise proctoring,
  - idle proctoring,
  - deep link exam,
  - experimental parser.
- Jika flag dimatikan, app fallback ke perilaku dasar tanpa crash atau block exam.

### 41.3 Backward Compatibility Expectation
- Frontend release `N` wajib kompatibel dengan backend API `N` dan `N-1` selama minimum 90 hari.
- Frontend harus mengabaikan field response baru yang tidak dikenali.
- Breaking API response harus dilindungi flag dan rollout bertahap.

### 41.4 Rollback Trigger & Procedure
Trigger rollback segera jika salah satu terjadi:
- crash-free < 99.0% selama 1 jam.
- submit failure naik > 2x baseline selama 30 menit.
- login failure naik > 2x baseline dan terkonfirmasi bukan issue backend.

Prosedur rollback:
1. Matikan fitur bermasalah lewat remote config (kill switch) dalam <= 5 menit.
2. Hentikan rollout store (freeze stage).
3. Rilis hotfix patch frontend.
4. Kirim incident note + recovery ETA ke stakeholder.

## 42. Sinkronisasi PRD Frontend vs PRD Backend

### 42.1 Aturan Sinkronisasi Utama
- Rule bisnis, validasi attempt, scoring, anti-cheat, dan idempotency mengikuti `Backend/PRD_BACKEND.md`.
- Representasi payload HTTP mengikuti kontrak endpoint backend aktif (OpenAPI/response runtime).
- Perbedaan notasi `snake_case` (domain/DB) vs `camelCase` (API JSON) harus ditangani via mapping eksplisit, bukan asumsi.

### 42.2 Field Naming Equivalence (Domain Backend <-> API Frontend)
| Domain/DB (Backend PRD) | API JSON (Frontend) | Scope |
|---|---|---|
| `attempt_limit` | `attemptLimit` | Subject payload |
| `duration_minutes` | `durationMinutes` | Subject payload |
| `allow_review` | `allowReview` | Subject payload |
| `subject_id` | `subjectId` | Question/Attempt |
| `correct_answer` | `correctAnswer` | Admin-only payload |
| `is_published` | `isPublished` | Exam payload |
| `start_time` | `startTime` | Exam/Attempt payload |
| `end_time` | `endTime` | Exam/Attempt payload |
| `attempt_no` | `attemptNo` | Attempt payload |
| `attempt_id` | `attemptId` | Answer/Result/Proctoring payload |
| `question_id` | `questionId` | Answer payload |
| `cheat_score` | `cheatScore` | Result payload |
| `risk_level` | `riskLevel` | Result payload |

### 42.3 Endpoint Alignment (Canonical + Alias)
| Capability | Canonical (Backend PRD) | Alias (Server Support) | Frontend Rule |
|---|---|---|---|
| List/Create/Update/Delete Subject | `/subjects` | `/api/subjects` | boleh pakai salah satu, konsisten per service |
| List Question by Subject | `/subjects/:id/questions` | `/api/subjects/:id/questions` | same response contract |
| Create/Update/Delete/Reorder Question | `/questions/*` | `/api/questions/*` | gunakan path yang tersedia di environment |
| Auth/Attempt/Answer/Proctoring/Submit/Result | sesuai PRD backend | tidak ada alias wajib | wajib sama dengan backend PRD |

### 42.4 Business Rule Cross-Check (Harus Sama)
| Rule Backend PRD | Dampak Wajib Frontend |
|---|---|
| Subject max 30 soal, total weight = 100 | frontend tampilkan error backend apa adanya, tidak override rule |
| Satu active attempt per user+exam+subject | route guard harus prioritaskan resume attempt aktif |
| Save answer overwrite/idempotent | frontend boleh kirim ulang payload answer yang sama |
| Submit idempotent + lock attempt | retry submit harus ke endpoint dan `attemptId` yang sama |
| Proctoring duplicate boleh | frontend tidak dedup event proctoring |
| `correct_answer` tidak dikirim ke siswa | frontend siswa dilarang menyimpan/menampilkan `correctAnswer` |

### 42.5 Prioritas Jika Dokumen Bertentangan
Urutan prioritas implementasi:
1. Behavior backend runtime (response aktual + rule validasi server).
2. OpenAPI backend (`/docs.json`).
3. `PRD_BACKEND.md` (rule bisnis/arsitektur).
4. PRD frontend ini (detail UI/state sebagai turunan backend).

## 43. Addendum Scope Implementasi (Tambahan yang Kini Resmi)

Section ini menetapkan fitur tambahan yang sudah ada di implementasi sebagai bagian resmi scope frontend.

### 43.1 Admin Operations Expansion (Mobile Admin)
Selain modul admin inti (`dashboard`, `subject`, `question`, `result`), frontend resmi mencakup:
- `Class Management` (`/admin/classes`)
- `Class Student Assignment` (`/admin/classes/:id/students`)
- `Class Subject Assignment` (`/admin/classes/:id/subjects`)
- `Student Account Management` (`/admin/students`)

Semua flow di atas dianggap bagian dari produk utama, bukan fitur eksperimen.

### 43.2 Student Identity Gate Sebelum Start Exam
Sebelum siswa dapat memulai ujian:
- `fullName` dan `rollNumber` wajib diisi.
- siswa harus sudah memiliki assignment kelas (`classId` / `className`) dari admin.

Jika syarat belum terpenuhi, frontend wajib menahan aksi start dan menampilkan pesan aksi yang jelas.

### 43.3 Routing Extension Policy
Rute tambahan berikut menjadi bagian kontrak navigasi resmi:
- `/admin/classes`
- `/admin/classes/:id/students`
- `/admin/classes/:id/subjects`
- `/admin/students`
- `/exam/:examId/start` (entry detail opsional)

Catatan:
- Entry utama siswa tetap dari `/exam` (subject-first start).
- `/exam/:examId/start` boleh dipakai untuk entry terarah (deep link/internal action) selama guard auth+role tetap berlaku.

### 43.4 Kontrak Endpoint Tambahan untuk Frontend
Frontend resmi menggunakan endpoint tambahan backend berikut:
- `GET/POST/PUT/DELETE /classes*` (admin only)
- `GET/POST/DELETE /students*` (admin only)
- `GET/PUT /users/me` (profile fetch/update)

Untuk kompatibilitas server saat ini:
- canonical: `/subjects`, `/questions/*`
- alias yang didukung: `/api/subjects`, `/api/questions/*`

### 43.5 Status Scope
Semua item di Section 43 bukan lagi "kelebihan", tetapi scope resmi PRD frontend.
