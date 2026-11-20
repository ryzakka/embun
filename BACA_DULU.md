# Embun — halaman publik untuk pengenalan dan kebijakan

Paket tambahan untuk proyek **Flutter/Dart Embun** yang memakai `https://embun.pages.dev/`. Halaman informasi berupa HTML/CSS statis dan dapat dibuka tanpa login. Tidak ada perubahan backend Supabase, SQL, kartu, ruangan, atau alur autentikasi.

## Salin ke proyek

1. Cadangkan berkas yang akan diganti.
2. Gabungkan isi folder **`web`** paket ke folder **`web`** proyek Flutter.
3. Gabungkan isi folder **`lib`** paket ke folder **`lib`** proyek Flutter.
4. Build dan deploy ulang melalui alur Cloudflare Pages yang biasa Anda gunakan.

Kali ini **folder `web` juga harus disalin**, bukan hanya `lib`. Tidak perlu Python, SQL, dependency baru, atau penambahan daftar aset di `pubspec.yaml` untuk berkas HTML/CSS ini.

Paket tidak mengganti `web/index.html`, bootstrap Flutter, manifest aplikasi, `_redirects`, atau `_headers`. Gim tetap di alamat utama `/`; halaman pengenalan ada di `/tentang/`. Isi `web` disertakan Flutter pada hasil build web; jangan mengunggah folder halaman ini sendirian sebagai pengganti seluruh situs gim.

```sh
flutter build web
```

Untuk unggahan manual, deploy **seluruh isi `build/web`** yang sudah berisi gim dan halaman informasi. Untuk pipeline GitHub/Cloudflare, masukkan folder sumber baru ke repository dan jalankan deployment seperti biasanya. Jika Anda menambahkan halaman ke build siap pakai tanpa rebuild, salin isi folder `web` paket ke output build yang sudah ada; simpan juga di folder sumber `web` agar tidak hilang pada build berikutnya.

Folder `diffs`, berkas pengujian, dan dokumen panduan tidak perlu dimasukkan ke situs. Bila `account_pages.dart` sudah dimodifikasi setelah paket login sebelumnya, gabungkan `diffs/account_pages.diff` secara manual agar desain lokal tidak tertimpa.

## Alamat untuk Branding Google

Setelah deployment berhasil, buka ketiga URL melalui jendela privat tanpa login. Pastikan halaman muncul sebagai informasi publik, bukan halaman login atau 404.

| Kolom di Google Auth Platform → Branding | Isi |
| --- | --- |
| Application home page | `https://embun.pages.dev/tentang/` |
| Application privacy policy link | `https://embun.pages.dev/privasi/` |
| Application terms of service link | `https://embun.pages.dev/ketentuan/` |

Simpan Branding. Lengkapi persyaratan domain atau data lain yang masih ditampilkan Google. Kembali ke Audience untuk memeriksa kelengkapan publikasi, lalu ikuti proses verifikasi branding yang tersedia. Pembuatan halaman tidak otomatis memublikasikan atau memverifikasi aplikasi di Google.

**Site URL Supabase tetap alamat gim `https://embun.pages.dev/`.** Callback Google juga tetap Callback URL Supabase yang sebelumnya sudah bekerja. Ketiga tautan di atas untuk bagian Branding, bukan pengganti callback OAuth. Paket ini tidak mengubah konfigurasi dashboard mana pun.

Jika halaman masih membuka Flutter/login, periksa apakah hasil deploy benar-benar memiliki `tentang/index.html`, `privasi/index.html`, dan `ketentuan/index.html`. Periksa juga aturan rewrite/redirect khusus yang mungkin sudah dibuat pada proyek Cloudflare. Paket mempertahankan konfigurasi Anda dan tidak menimpa aturan tersebut.

## Isi paket

| Berkas | Fungsi |
| --- | --- |
| `web/tentang/index.html` | Pengenalan gim, cara bermain, penggunaan profil, kontak, dan tautan kebijakan |
| `web/privasi/index.html` | Data Google, profil, sesi, permainan/chat, penyedia, retensi, dan permintaan terkait data |
| `web/ketentuan/index.html` | Ketentuan akun, perilaku pemain, percakapan, ketersediaan layanan, dan kontak |
| `web/informasi/embun.css` | Desain bersama halaman publik |
| `web/informasi/logo.webp` dan `desa.webp` | Ilustrasi dari aset Embun yang sudah tersedia |
| `lib/features/account/public_information_links.dart` | Tautan Tentang, Privasi, Ketentuan; membuka tab/browser tanpa membawa query/token login |
| `lib/features/account/account_pages.dart` | Versi halaman login/profil sebelumnya dengan penambahan tautan informasi |

Halaman web tidak memuat JavaScript, login SDK, Google Fonts, formulir data, atau pelacak. Hosting tetap dapat memproses data teknis koneksi sesuai kebijakan penyedianya. Tautan kebijakan di aplikasi dibuka pada tab/browser terpisah untuk mempertahankan layar login/profil yang sedang dipakai.

## Kontak dan isi kebijakan

Email publik **`dhi.mas26wnz@gmail.com`** digunakan sesuai konfirmasi Anda pada percakapan. Jika hendak menggantinya, ubah seluruh kemunculan alamat tersebut pada tiga berkas HTML sebelum deployment.

Isi kebijakan disusun dari kode akun/permainan yang diperiksa: Google + Supabase Auth, nama panggilan/avatar, sesi lokal, data room/chat/tindakan, serta penyajian situs melalui Cloudflare. Paket tidak menetapkan batas retensi atau menjanjikan penghapusan otomatis yang tidak ada di kode. Permintaan data/penghapusan diarahkan ke email pengelola, dan perlu benar-benar ditangani oleh pengelola.

Sebelum menerbitkan, pastikan penjelasan penggunaan data sesuai konfigurasi dan fitur produksi Anda, terutama jika ada analytics, iklan, penyedia tambahan, atau aturan retensi di luar berkas yang tersedia. Tautan Google/Supabase/Cloudflare pada kebijakan merujuk ke kebijakan penyedia masing-masing.

Untuk mengubah desain melalui Claude: kirim ketiga berkas HTML dan `web/informasi/embun.css`, beserta aset gambar jika diperlukan. Desain tombol informasi di Flutter berada di `public_information_links.dart`.

Lihat `HASIL_PENGUJIAN.md` untuk ruang lingkup validasi dan hal yang belum diverifikasi.
