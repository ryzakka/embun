# Validasi lokal — tamu dan akun Google

20 November 2026. Flutter 3.38.10 / Dart 3.10.9.

| Pemeriksaan | Hasil |
| --- | --- |
| Alur tamu, restore, gagal masuk, respons terlambat, link dan login akun lama | 12 tes lulus, termasuk widget dan adapter HTTP anonim |
| Create/join ruangan tamu dan nama otomatis akun Google | 3 tes lulus memakai RPC HTTP tiruan |
| Regresi Google, penyimpanan profil, pergantian akun, layout dan preview | 21 tes lulus |
| Profil publik/pribadi, avatar, riwayat, gelar, penghapusan, lobi dan ending | 15 tes lulus |
| Database lokal PostgreSQL melalui PGlite | 64 pengecekan lulus, termasuk 41 regresi profil |
| Build web lib/account_preview_main.dart | Berhasil, 30,3 detik |
| Analisis tipe berkas terkait | Tidak ada error; warning/info tersisa pada helper UI lama/berkas redesign |

Dua ekspektasi teks pada test/account_test.dart diperbarui menjadi key tombol
google-login, karena desain terbaru memakai label Login dengan Google. Perilaku
yang diuji tetap sama. Fixture pengujian Supabase menggunakan penyimpanan dan
HTTP tiruan; tidak menghubungi backend produksi.

## Cakupan penting

- Tamu bisa masuk tanpa editor profil. Model yang anonim tetap dianggap belum
  terhubung walaupun metadata tampilannya berisi tulisan provider Google.
- Sesi tamu dipakai ulang; tidak membuat pengguna anonim baru pada setiap aksi.
- Respons masuk tamu yang terlambat tidak menimpa akun lain yang sudah diterima.
- Membuka browser OAuth belum dianggap sukses. Status Google baru diterima dari
  sesi terverifikasi; penautan dengan UID yang sama tetap membersihkan route tamu.
- Tamu mengirim nama ruangan yang diisi. Google mengirim nama akun tersimpan.
- Profil tamu tidak merender statistik/riwayat/kontrol pribadi walaupun respons
  tiruan sengaja membawa nilai statistik. Ikon G hanya untuk akun terhubung.
- Badge roster mengambil satu daftar terbatasi per ruangan dan memuat ulang
  ketika peserta berganti. Kegagalan memuat tidak dilabeli sebagai status tamu.
- Profil/daftar badge ditolak server bagi orang luar dan selama pertandingan.
- SQL memeriksa auth.identities serta is_anonymous, bukan metadata nama/avatar.
- Pertandingan tamu tidak menjadi hasil akun setelah tautan selesai, termasuk
  saat menautkan di tengah pertandingan dan saat migrasi dijalankan ulang.
- Hasil Google lama tetap ada; email dan status penghapusan tetap privat.

## Batas

Pengujian OAuth Google nyata, toggle konfigurasi dashboard, multiplayer pada
Supabase produksi dan deployment belum dilakukan. SQL disiapkan untuk dipasang
pengelola. Test PostgreSQL memakai schema fixture, bukan salinan data produksi.

Build yang berhasil adalah pratinjau akun/tamu. Build seluruh gim tidak diulang:
arsip lengkap yang tersedia mempunyai ketidakcocokan berkas suasana desa/animasi
malam yang sudah diketahui sebelumnya. Ini tidak menyatakan proyek lokal Anda
yang berjalan memiliki masalah yang sama.

Tes Flutter dalam paket dapat digabungkan ke test/ proyek dan dijalankan dengan
flutter test. Tes SQL membutuhkan Node dan @electric-sql/pglite@0.5.17, lalu:

```sh
node guest_sql_test.mjs /jalur/20261120120000_profil_pemain.sql /jalur/20261120160000_tamu_google.sql
```

Letakkan salinan verification/guest_sql_test.mjs di folder Node yang memiliki
dependensi tersebut. Seluruh database tes berada dalam memori.
