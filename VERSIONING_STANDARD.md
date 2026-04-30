# Standar Versi Desktop & Mobile (4 Digit)

Dokumen ini menjadi acuan resmi penulisan versi untuk:
- `Desktop` (Electron)
- `Mobile` (Flutter Frontend)

Format versi publik yang dipakai:

`MAJOR.MINOR.PATCH.BUILD`

Contoh: `1.0.0.0`

## 1. Arti Tiap Digit

1. `MAJOR` (angka ke-1)
- Naik jika ada perubahan besar yang tidak kompatibel.
- Contoh:
  - Perubahan alur login/ujian yang membuat klien lama tidak bisa dipakai normal.
  - Perubahan kontrak API/protocol penting yang membutuhkan update wajib.
  - Penghapusan fitur utama atau perubahan behavior inti yang breaking.

2. `MINOR` (angka ke-2)
- Naik jika ada fitur baru yang kompatibel dengan versi sebelumnya.
- Contoh:
  - Tambah halaman/fitur baru (misalnya halaman Mata Pelajaran khusus siswa).
  - Tambah kemampuan monitoring baru tanpa mematahkan alur lama.

3. `PATCH` (angka ke-3)
- Naik jika ada perbaikan bug, security fix, atau improvement kecil tanpa fitur baru besar.
- Contoh:
  - Perbaikan hitungan percobaan ujian.
  - Perbaikan live preview/pengawasan yang salah kondisi.

4. `BUILD` (angka ke-4)
- Naik untuk revisi rilis yang tidak mengubah scope fitur utama.
- Contoh:
  - Rebuild installer/apk dengan isi code yang setara.
  - Perbaikan teks/UI minor, metadata, atau penyesuaian packaging.
  - Penyesuaian konfigurasi rilis non-breaking.

## 2. Aturan Reset Saat Angka Naik

1. Jika `MAJOR` naik, maka `MINOR.PATCH.BUILD` harus di-reset ke `0`.
2. Jika `MINOR` naik, maka `PATCH.BUILD` harus di-reset ke `0`.
3. Jika `PATCH` naik, maka `BUILD` harus di-reset ke `0`.
4. Jika hanya `BUILD` naik, tiga angka sebelumnya tetap.

Contoh urutan valid:
- `1.4.2.7` -> `1.4.3.0` (patch release)
- `1.4.3.0` -> `1.5.0.0` (minor release)
- `1.5.0.0` -> `2.0.0.0` (major release)

## 3. Mapping Teknis per Platform

### Desktop (Electron)

`package.json` mengikuti SemVer 3 digit, jadi gunakan:
- `Desktop/package.json` -> `version = MAJOR.MINOR.PATCH`
- Angka `BUILD` dicatat di changelog rilis dan tag Git.

Format tag yang wajib:
- `desktop/vMAJOR.MINOR.PATCH.BUILD`
- Contoh: `desktop/v1.2.3.4`

### Mobile (Flutter)

Flutter sudah mendukung pemisahan `name+build`:
- `Frontend/pubspec.yaml` -> `version: MAJOR.MINOR.PATCH+BUILD`
- Representasi publik 4 digit tetap dibaca sebagai `MAJOR.MINOR.PATCH.BUILD`.

Contoh:
- `version: 1.2.3+4` berarti versi publik `1.2.3.4`.

## 4. Kapan Desktop dan Mobile Naik Bersamaan

1. Jika fitur baru muncul di dua platform, naikkan minimal `MINOR` di dua-duanya.
2. Jika bug hanya di satu platform, cukup naikkan `PATCH/BUILD` di platform tersebut.
3. Jika ada breaking change lintas platform, naikkan `MAJOR` pada semua platform terdampak.

## 5. Wajib Catat Perubahan (Release Notes)

Setiap rilis wajib menuliskan:
- Tanggal rilis
- Platform (`Desktop` / `Mobile`)
- Versi lama -> versi baru
- Jenis kenaikan (`major/minor/patch/build`)
- Ringkasan perubahan
- Dampak ke user
- Catatan kompatibilitas (jika ada)

Template yang dipakai:

```md
## [Platform] vX.Y.Z.W - YYYY-MM-DD
- Tipe rilis: major | minor | patch | build
- Ringkasan:
  - ...
- Dampak user:
  - ...
- Kompatibilitas:
  - ...
```

## 6. Checklist Sebelum Rilis

1. Tentukan tipe perubahan: major/minor/patch/build.
2. Naikkan nomor versi sesuai aturan reset.
3. Pastikan versi di file teknis sudah benar:
- Desktop: `Desktop/package.json`
- Mobile: `Frontend/pubspec.yaml`
4. Tulis release notes sesuai template di atas.
5. Buat tag Git sesuai format platform.
6. Push commit + tag.

## 7. Contoh Keputusan Cepat

1. Tambah fitur baru sidebar Mata Pelajaran siswa:
- `1.3.2.5` -> `1.4.0.0` (minor)

2. Perbaiki bug live monitoring tidak tampil:
- `1.4.0.0` -> `1.4.1.0` (patch)

3. Rebuild installer karena metadata/icon berubah, logic sama:
- `1.4.1.0` -> `1.4.1.1` (build)

---

Jika ada kasus abu-abu, prioritaskan konsistensi:
- Ada perubahan behavior user yang nyata -> minimal `PATCH`.
- Hanya repack/relabel tanpa perubahan behavior -> `BUILD`.
