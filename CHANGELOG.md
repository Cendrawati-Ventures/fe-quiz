# Release Notes

## Mobile v1.1.1.9 - 2026-11-25
- Tipe rilis: patch
- Ringkasan:
  - Menambahkan batas waktu saat kamera dan koneksi Agora tidak merespons.
  - Menampilkan tahap persiapan kamera/mikrofon secara langsung pada layar.
  - Memperbaiki status koneksi monitoring yang sebelumnya dapat tertahan di "Belum terhubung".
  - Menjalankan status realtime Firebase tanpa menahan preview kamera.
- Dampak user:
  - Loading tidak berputar tanpa akhir dan kegagalan dapat dicoba ulang tanpa menutup aplikasi.
  - Siswa mendapat petunjuk yang jelas bila izin, kamera, atau internet bermasalah.
- Kompatibilitas:
  - Tidak mengubah data ujian dan tetap kompatibel dengan backend sebelumnya.

## Mobile v1.1.0.8 - 2026-11-23
- Tipe rilis: build
- Ringkasan:
  - Menandai fitur perangkat keras Wi-Fi sebagai opsional pada Android.
- Dampak user:
  - Aplikasi tersedia untuk lebih banyak perangkat yang kompatibel.
- Kompatibilitas:
  - Tidak mengubah fitur atau data pengguna dari v1.1.0.7.

## Mobile v1.1.0.7 - 2026-11-23
- Tipe rilis: minor
- Ringkasan:
  - Menambahkan gambar pada setiap opsi jawaban pilihan ganda.
  - Mempercepat persiapan kamera dan mikrofon sebelum ujian.
  - Memperbaiki urutan koneksi monitoring agar Firebase tidak menahan kamera.
- Dampak user:
  - Admin dapat membuat soal pilihan ganda dengan jawaban berupa gambar.
  - Siswa dapat melihat dan memilih gambar langsung dari kartu jawaban.
  - Halaman pemeriksaan perangkat lebih cepat menampilkan kamera.
- Kompatibilitas:
  - Soal lama tanpa gambar tetap dapat digunakan.
  - Backend terbaru harus diterapkan sebelum soal bergambar dibuat.
