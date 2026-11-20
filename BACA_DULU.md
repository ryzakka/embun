# Embun Flutter — Tamu dan akun Google, dengan UI terbaru

Paket ini memakai tiga berkas UI terbaru yang Anda kirim: account_pages.dart,
profile_details_page.dart, dan google_sign_in_button.dart. Tampilan hasil redesign
dipertahankan; perubahan menyambungkan mode tamu, penanda Google, dan penyimpanan.

## Pasang

1. Cadangkan proyek. Gabungkan seluruh folder **lib/** ke proyek Flutter dan
   timpa berkas yang sama. Jangan hanya menyalin tiga berkas UI, dan jangan
   menghapus berkas proyek lainnya. Tidak perlu mengganti main.dart.
2. Gabungkan **web/privasi/index.html**. Halaman tersebut menjelaskan sesi tamu
   dan perbedaan penyimpanan hasil. web/index.html dan berkas verifikasi Google
   Anda tidak diganti.
3. Di Supabase SQL Editor, jalankan **20261120160000_tamu_google.sql** dari
   supabase/migrations/. Ini pembaruan fitur profil sebelumnya. Jika SQL profil
   **20261120120000_profil_pemain.sql** belum pernah dipasang, jalankan berkas
   tersebut terlebih dahulu, lalu SQL tamu. Jangan menjalankan SQL profil lama
   sendirian setelah SQL tamu, karena fungsi profil lama akan menggantikan versi
   baru. Jalankan SQL tamu lagi jika terlanjur melakukan itu.
4. Periksa **Authentication** di dashboard Supabase:
   - **Allow anonymous sign-ins** harus aktif untuk Main sebagai tamu.
   - **Allow manual linking / Enable Manual Linking** harus aktif untuk
     menautkan sesi tamu ke Google.
   - Google OAuth, callback, dan redirect yang sebelumnya berhasil tetap dipakai.
   Pengaturan ini tidak diubah otomatis oleh paket. Jika sudah aktif, tidak perlu
   diubah lagi. Rujukan resmi ada di bagian akhir dokumen ini.
5. Avatar PNG/WebP tetap di assets/avatars/ dan tetap terdaftar di pubspec.yaml.
   Tidak ada gambar baru yang perlu dipasang. Jalankan `flutter pub get`, lalu
   jalankan/build aplikasi asli seperti biasa. Entry point produksi: lib/main.dart.

Tidak memerlukan installer Python. Folder test/ dan verification/ bersifat
opsional untuk pengujian. Supabase produksi belum diubah oleh pekerjaan ini.

## Alur pemain

- **Login awal:** Login dengan Google atau **Main sebagai tamu**.
- **Tamu:** mendapat sesi anonim Supabase untuk bermain. Langsung masuk menu,
  tanpa mengatur profil akun. Nama diisi saat membuat/bergabung ke ruangan.
  Sesi yang masih tersimpan pada perangkat dapat dipulihkan saat membuka kembali
  aplikasi. Keluar sesi atau menghapus penyimpanan browser dapat membuat sesi
  tamu tersebut tidak bisa dilanjutkan lagi.
- **Menu tamu:** keterangan **Bermain sebagai tamu**, tombol **Tautkan Google**,
  serta halaman informasi sesi. Tidak ada editor nama akun/avatar, gelar akun,
  statistik atau riwayat akun bagi tamu.
- **Akun Google:** tetap memakai nama tersimpan secara otomatis, avatar, gelar,
  statistik, riwayat, email pribadi, keluar akun dan permintaan penghapusan.
- **Penanda:** ikon G empat warna pada avatar akun sendiri, profil publik dan
  tombol profil dalam daftar pemain lobi/ending berarti terhubung ke Google.
  Penanda orang berarti belum terhubung. Jika status belum berhasil dimuat,
  aplikasi tidak menebaknya sebagai tamu.
- **Rincian tamu:** menampilkan nama di ruangan dan
  **Pengguna belum menautkan akun Google.** Tidak menampilkan statistik atau
  riwayat akun. Tidak ada tombol menautkan untuk akun orang lain.
- Profil pemain lain tetap hanya bisa dibuka di lobi atau ending, oleh sesama
  peserta ruangan. Tidak ada daftar teman, undangan atau blokir.

## Menautkan dan memakai akun Google lama

**Tautkan ke Google** menggunakan Supabase `linkIdentity()`. Identitas sesi tamu
tetap sama saat berhasil ditautkan. Setelah callback Google terverifikasi,
aplikasi membersihkan navigasi tamu dan meminta pengaturan profil pertama bila
dibutuhkan. Membuka halaman Google saja belum dianggap berhasil menautkan akun.

Jika Google sudah pernah dipakai untuk akun Embun lain, pilih **Masuk ke akun
Google yang sudah ada**. Ini menggunakan login biasa dan mengganti sesi dengan
akun tersebut. Tidak ada penggabungan akun atau pemindahan hasil tamu. Bila
proses penautan masih menunggu, tekan Batalkan / coba lagi dahulu sebelum
memilih login ke akun lama. Akun Google lama mempertahankan profil dan hasilnya.

## Hasil permainan dan data tamu

Permainan yang dimulai sebagai tamu **tidak dimasukkan ke statistik atau riwayat
akun**, termasuk jika pemain menautkan Google di tengah atau sesudah permainan
tersebut. Pencatatan akun berlaku untuk pertandingan baru yang dimulai setelah
akun sudah terhubung. Nama/gelar/statistik hasil versi Google sebelumnya tetap
terpelihara. Hasil tamu lama tidak diimpor saat SQL dijalankan ulang.

Sesi anonim tetap mempunyai pengenal teknis Auth. Keanggotaan ruangan, kartu,
tindakan dan data operasional pertandingan tetap diproses oleh backend gim,
agar permainan multiplayer dapat berjalan. Pesan “belum disimpan di akun”
merujuk pada profil/statistik/riwayat akun; bukan janji bahwa tidak ada data
operasional permainan di server.

SQL tambahan tidak mengganti RPC create_game, join_game, start_game atau aturan
permainan. Fungsi profil memeriksa identitas Google di server; user_metadata
yang dapat diedit pemain tidak dipakai untuk menentukan badge atau kelayakan
statistik. Email dan permintaan penghapusan tetap tidak dikirim ke profil publik.

## Coba setelah dipasang

1. Buka sesi privat/incognito → Main sebagai tamu → buat ruangan dengan nama.
   Periksa bahwa tidak ada pengaturan profil sebelum masuk menu.
2. Masuk dari akun Google lain ke ruangan yang sama. Periksa penanda G pada akun
   Google dan keterangan belum menautkan pada rincian tamu.
3. Selesaikan pertandingan dan buka ending. Akun Google mendapat hasilnya satu
   kali; pemain tamu tidak mempunyai statistik/riwayat akun.
4. Dari menu tamu, tautkan Google baru atau masuk ke akun Google lama. Setelah
   berhasil, buat pertandingan baru untuk memulai pencatatan akun.

`flutter run -d chrome -t lib/account_preview_main.dart` tetap tersedia untuk
pratinjau lokal bertanda PRATINJAU LOKAL. Mode itu memakai data contoh dalam
memori, tanpa Google atau Supabase nyata. Jangan deploy target pratinjau sebagai
gim produksi. Lihat HASIL_PENGUJIAN.md untuk hasil dan batas validasi.

## Rujukan konfigurasi

- https://supabase.com/docs/guides/auth/auth-anonymous
- https://supabase.com/docs/reference/dart/auth-linkidentity
- https://supabase.com/docs/guides/auth/general-configuration
