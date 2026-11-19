# Hasil pengujian login dan profil Embun

## Hasil yang sudah berhasil

- **21 tes lulus** pada `test/account_test.dart` menggunakan Flutter 3.38.10 / Dart 3.10.9 dan dependency Supabase dari lockfile proyek.
- **Dart analyze: No issues found** untuk berkas akun/profil baru, entry point pratinjau, dan pengujiannya.
- **Build web pratinjau akun berhasil** melalui `lib/account_preview_main.dart` dalam 34,4 detik.
- **8 skenario installer lulus**: dry-run; pemasangan/cadangan lima berkas asal; pemasangan ulang; konflik berkas asal; konflik berkas baru; CRLF; payload berbeda dari manifest; dependency Supabase yang belum ada.

## Yang diuji

1. Nama Google hanya dipakai sebagai isian awal; nama panggilan tersimpan dipertahankan pada login berikutnya.
2. Validasi nama kosong, batas panjang visual, kontrol karakter, dan normalisasi spasi.
3. URL kembali mempertahankan path aplikasi dan membuang query/fragment lama.
4. Identitas Google diperiksa dari provider autentikasi, bukan metadata pengguna yang dapat diedit.
5. Pemulihan profil lengkap tidak meminta login/profil lagi.
6. Sesi Google baru masih membutuhkan pengisian profil satu kali.
7. Pembukaan browser tidak dianggap login berhasil; pembatalan/coba lagi tetap tersedia.
8. Batas waktu menunggu OAuth tidak meloloskan pengguna tanpa sesi.
9. Gagal membuka browser dan ketukan ganda ditangani.
10. Sesi baru mengalahkan hasil pemulihan akun lama yang terlambat.
11. Gagal menyimpan mempertahankan profil sebelumnya dan dapat dicoba ulang.
12. Respons simpan lama tidak menimpa akun baru.
13. Galat stream autentikasi ditangani tanpa exception yang tidak tertangani.
14. Kegagalan dan keberhasilan keluar akun ditangani.
15. Adapter Supabase diuji dengan HTTP mock: hanya `PUT /auth/v1/user` untuk tiga metadata profil; metadata lain dipertahankan, dan user ID yang berbeda ditolak.
16. UI pengaturan pertama dan kunjungan berikutnya memakai profil tersimpan.
17. Pergantian user membersihkan seluruh navigasi; pembaruan profil/token pada user yang sama mempertahankannya.
18. Login/form profil tidak mengalami overflow pada layar 320×600 dengan skala teks 1,5.
19. Buat Ruangan melewati nama, melewati lima langkah tersisa, lalu mengirim nama tersimpan.
20. Gabung dengan kode menampilkan nama profil tanpa field nama yang dapat diedit.
21. Pratinjau lokal dapat melakukan simulasi masuk, simpan, edit profil, dan keluar tanpa Google/Supabase.

## Hambatan yang terpisah dari perubahan akun

Build `lib/main.dart` pada kumpulan sumber yang tersedia **belum berhasil**. Compiler menemukan ketidakcocokan lama pada:

- `lib/features/table/village_visit_view.dart` mengimpor `village_ambience.dart` yang tidak tersedia; komponen seperti `PlaceVoice` dan `PopupCharacter` ikut tidak ditemukan.
- `lib/features/table/night_scene.dart` memerlukan `NightImpactStage`, `kNightImpactMs`, `NightImpact.hit`, dan `NightImpact.shakePower` yang tidak ada pada versi `night_impact.dart` yang tersedia. Ada juga perbedaan argumen `NightImpactReport`.

Arsip tersimpan diperiksa, tetapi pasangan implementasi lengkap yang cocok tidak ditemukan. Paket ini tidak mengganti komponen malam/kunjungan dengan stub atau menurunkan versinya. Karena itu keberhasilan build pratinjau **tidak diklaim sebagai keberhasilan build seluruh gim**. Untuk build aplikasi penuh, pasangan berkas malam/kunjungan yang sesuai dari proyek pengguna tetap diperlukan.

Analisis integrasi awal juga memperlihatkan diagnostik gaya/deprecation yang sudah ada pada berkas sumber lama. Berkas akun baru dan pengujiannya sudah bersih; paket tidak melakukan pembersihan menyeluruh kode lama.

## Belum diuji secara nyata

OAuth Google hidup, konfigurasi dashboard, pemulihan setelah reload browser nyata, pengujian beberapa perangkat, login APK/deep link Android, multiplayer produksi, dan deployment. Semua tes HTTP menggunakan mock; tidak ada permintaan ke Supabase produksi dan tidak ada perubahan konfigurasi dashboard/SQL yang dijalankan.

Pengujian menggunakan `CI=true` dan `FLUTTER_SUPPRESS_ANALYTICS=true`. Dependensi sudah disiapkan sebelum `--no-pub`.

```sh
flutter test --no-pub test/account_test.dart --reporter expanded
flutter build web --no-pub --no-web-resources-cdn -t lib/account_preview_main.dart
```

Referensi konfigurasi resmi:

- https://supabase.com/docs/guides/auth/social-sign-in/auth-google
- https://supabase.com/docs/reference/dart/auth-signinwithoauth
- https://supabase.com/docs/reference/dart/auth-updateuser
- https://supabase.com/docs/guides/auth/redirect-urls
- https://supabase.com/docs/guides/auth/native-mobile-deep-linking
