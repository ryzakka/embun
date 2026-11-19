# Embun — Login Google dan profil

Paket perubahan untuk proyek Flutter Embun, berdasarkan `lobby_page.dart` dan `room_entry_view.dart` terbaru yang dikirim. Ini bukan paket Godot. Login Google memakai Supabase Auth yang sudah ada; tidak memerlukan package Google tambahan, SQL, tabel profil, atau perubahan aturan permainan.

## Perilaku

- Sebelum memasuki gim, pemain masuk melalui **Masuk dengan Google**.
- Pada login pertama, nama Google menjadi isian awal **nama panggilan**. Pemain mengonfirmasinya satu kali dan memilih avatar.
- Nama panggilan dan avatar disimpan pada metadata akun: `embun_nickname`, `embun_avatar`, dan `embun_profile_version`. Login berikutnya memakai nama yang sudah disimpan, bukan menimpanya dengan nama Google lagi.
- Sesi dipulihkan oleh Supabase Flutter; sesi kedaluwarsa diperbarui bila memungkinkan. Pemain tidak diminta login lagi selama sesi dapat dipulihkan.
- Menu menampilkan nama, avatar, dan tombol **Profilku**. Nama dapat diubah, dan tombol Keluar akun mengakhiri sesi pada perangkat itu.
- **Buat Ruangan** melewati langkah nama: tema → akses → durasi → Si Terbisik → ringkasan. **Gabung Ruangan** menampilkan nama profil tanpa kolom nama. Tema Manhwa dan pengaturan ruangan tetap dipertahankan.
- Nama profil dipakai ketika membuat/bergabung ke room. Mengedit profil tidak mengubah `game_players` atau nama dalam pertandingan berjalan. Aturan anonimisasi/nama karakter yang diterapkan server selama pertandingan tetap mengikuti implementasi permainan sebelumnya.
- Avatar adalah ikon profil pada menu/pengaturan, bukan pengganti kartu karakter atau pakaian Manhwa. Email hanya ditampilkan di profil pribadi dan tidak dikirim sebagai nama pemain.
- Pergantian akun atau sign-out membersihkan tumpukan navigasi lama. Pembaruan token/profil pada akun yang sama tidak mengeluarkan pemain dari layar permainan.
- Pembukaan browser Google bukan bukti login berhasil: aplikasi menunggu perubahan sesi autentikasi. Ada tombol coba lagi dan batas waktu tampilan tunggu, sehingga pembatalan login tidak membekukan layar.

## Pasang berkas

Ekstrak paket ke folder terpisah. Dari folder paket jalankan:

```sh
python pasang_patch.py --project "C:/jalur/ke/embun" --check
python pasang_patch.py --project "C:/jalur/ke/embun"
```

Pada Windows, `py` dapat menggantikan `python`. Installer memeriksa hash semua berkas dahulu. Jika berkas tujuan sudah diubah, ia berhenti tanpa menimpa berkas lain. Cadangan dibuat sebelum menyalin berkas asal. Gunakan berkas di folder `diffs` untuk menggabungkan perubahan manual jika versi lokal sudah berbeda.

Alternatif: gabungkan folder `lib` dan `test` secara manual. Periksa perubahan lokal sebelum mengganti berkas yang sudah ada. Tidak ada `pubspec.yaml` atau konfigurasi Supabase pengganti di paket. Dependency `supabase_flutter` dan `url_launcher` sudah tersedia pada sumber Embun yang diperiksa.

Lalu jalankan dari folder proyek:

```sh
flutter pub get
flutter run -d chrome -t lib/account_preview_main.dart
```

Pratinjau ini **lokal dan diberi label PRATINJAU LOKAL**: tombol Google mensimulasikan sesi contoh, tanpa menghubungi Google atau Supabase. Data contoh hilang ketika aplikasi dimulai ulang. Entry point produksi tetap `lib/main.dart`, yang selalu memakai Supabase sungguhan dan tidak memiliki pilihan melewati login.

Untuk mencoba produksi di web setelah menyelesaikan konfigurasi berikut:

```sh
flutter run -d chrome --web-port 7357
```

## Aktivasi Google — diperlukan satu kali

Kode sudah terhubung ke Supabase Auth, tetapi login nyata membutuhkan OAuth client milik proyekmu. Konfigurasi dashboard belum diubah oleh paket ini.

1. Buka Supabase Dashboard → proyek Embun → **Authentication → Sign In / Providers → Google**. Salin **Callback URL** yang diberikan dashboard.
2. Di Google Cloud / Google Auth Platform, pilih proyek, isi Branding/Audience/Data Access untuk aplikasi Embun. Gunakan akses dasar identitas Google; jangan menambahkan akses Drive, Gmail, atau scope lain yang tidak dipakai. Jika aplikasi masih berstatus Testing, tambahkan akun penguji.
3. Buat OAuth client bertipe **Web application**. Daftarkan origin web gim dan `http://localhost:7357` untuk pengujian. Pada **Authorized redirect URIs**, gunakan Callback URL Supabase dari langkah 1, bukan URL halaman Flutter.
4. Salin **Client ID** dan **Client Secret** ke pengaturan Google pada Supabase, lalu aktifkan provider Google. Client Secret disimpan di dashboard Supabase; jangan memasukkannya ke Dart, GitHub, atau chat.
5. Pada Supabase **Authentication → URL Configuration**, atur Site URL ke alamat utama web Embun. Tambahkan URL kembali yang tepat ke Redirect URLs: URL web aplikasi (termasuk subfolder jika ada) serta `http://localhost:7357/` untuk pengujian. Kode mengambil origin/path dari alamat aplikasi yang sedang dibuka dan menghapus query/fragment OAuth lama.
6. Jalankan aplikasi produksi. Coba login pertama, simpan profil, muat ulang, buat/gabung room, ubah profil, dan login dari perangkat lain dengan akun Google yang sama.

Pengaturan ini menambahkan Google pada proyek Supabase yang ada. **Jangan menonaktifkan anonymous sign-in atau mengganti RLS/RPC lama** hanya untuk memasang paket ini; versi Flutter lama masih dapat memerlukannya. Klien baru berhenti membuat akun anonim dan meminta profil Google sebelum membuat/bergabung ke room. Ini adalah aturan klien baru, bukan perubahan kebijakan akses server bagi klien lama.

Akun anonim lama tidak otomatis digabungkan dengan akun Google. Jika Google belum pernah terhubung, login menghasilkan akun permanen tersendiri; sesi/riwayat milik user anonim tetap terpisah. Paket tidak menjalankan migrasi pengguna atau mencoba mengaitkan akun secara diam-diam.

## Android

Login Android memakai browser eksternal kemudian kembali ke aplikasi melalui `com.ryzakka.embun://login-callback/`. Tambahkan URL itu ke Redirect URLs Supabase dan gabungkan isi `android-login-callback.xml` ke activity utama dalam `android/app/src/main/AndroidManifest.xml`. Pertahankan intent-filter launcher dan konfigurasi lain. Pastikan aplikasi release sudah memiliki permission INTERNET.

Berkas manifest Android terkini tidak tersedia pada bahan yang diperiksa, sehingga paket menyertakan potongan konfigurasi, bukan menimpa manifest proyek. Registrasi deep link dan uji login APK pada perangkat nyata tetap perlu dilakukan. Web tidak memerlukan perubahan manifest Android. Platform native lain memerlukan registrasi skema yang sesuai sebelum diuji.

## Berkas untuk desain di Claude

| Bagian | Berkas |
| --- | --- |
| Tampilan login, form profil, avatar | `lib/features/account/account_pages.dart` |
| Warna/tema bersama | `lib/features/common/ornate.dart` dari proyek |
| Nama/avatar/tombol profil di menu | `lib/features/lobby/lobby_page.dart` |
| Lima langkah Buat Ruangan | `lib/features/lobby/room_entry_view.dart` |
| Nama profil pada Gabung Ruangan | `lib/features/lobby/public_rooms_page.dart` |

Logika sesi berada di `data/account_controller.dart` dan `data/supabase_account_repository.dart`; pertahankan pemisahan antara browser terbuka dan sesi login berhasil, serta jangan memasukkan role/izin ke metadata profil yang bisa diedit pengguna.

Lihat `HASIL_PENGUJIAN.md` untuk hasil dan keterbatasan validasi.
