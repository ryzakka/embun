# Validasi halaman publik Embun

## Hasil

| Pemeriksaan | Hasil |
| --- | --- |
| Dart analyze untuk tautan informasi, halaman akun yang diubah, dan tes baru | No issues found |
| Tes tujuan URL dan tautan pada login/profil pertama | 2 tes lulus |
| Regresi layout login/profil pada layar 320×600 dengan teks 1,5× | 1 tes lulus |
| Build web pratinjau akun dengan tautan dan halaman statis baru | Berhasil, build final 26,4 detik |
| Salinan hasil build dibandingkan dengan sumber HTML/CSS/gambar | Identik |
| Permintaan HTTP lokal untuk 3 halaman, 3 aset, dan root aplikasi | 7 rute memberi HTTP 200 |
| Tautan internal dan anchor daftar isi | Seluruh tujuan tersedia |
| Dokumen publik tanpa JavaScript/form/login SDK | Ketiga halaman lulus |
| Konsistensi kontak, bahasa, canonical, H1, dan navigasi aktif | Lulus |

Lingkungan Flutter 3.38.10 / Dart 3.10.9. Pengujian memakai `CI=true` dan `FLUTTER_SUPPRESS_ANALYTICS=true`. Pemeriksaan HTTP menggunakan server lokal yang menyajikan hasil build; tidak memakai akun pengguna atau koneksi Supabase.

## Ruang lingkup

- Paket menambahkan enam berkas statis di bawah `web/tentang`, `web/privasi`, `web/ketentuan`, dan `web/informasi`.
- `web/index.html` tidak ada dalam paket dan tidak diganti. Aplikasi tetap di root, dan halaman informasi berdiri sendiri tanpa bootstrap Flutter.
- Dua berkas Dart mengatur tautan informasi pada login dan profil. URL hanya berisi origin serta path halaman yang diizinkan, tanpa query atau fragment OAuth.
- Isi akun, sesi, permainan/chat, dan metadata yang dijelaskan dalam kebijakan diperiksa dari sumber Flutter yang tersedia. Tidak ada penambahan provider login, scope, database, atau penyedia analytics.
- Email publik disetujui pengguna dalam percakapan untuk digunakan sementara. Kode tidak mengirim email secara otomatis; tautan `mailto:` membuka aplikasi email pengguna.

## Batas pemeriksaan

Halaman belum di-deploy ke `embun.pages.dev` oleh pekerjaan ini. Belum dilakukan pemeriksaan visual browser langsung, pengujian email masuk, audit seluruh konfigurasi produksi, atau verifikasi Google/Search Console. CSS menyediakan tata letak responsif; uji perangkat nyata tetap dapat dilakukan setelah deployment.

Build yang berhasil adalah entry point pratinjau akun, sekaligus membuktikan berkas publik disertakan di output Flutter. Build seluruh gim/multiplayer tidak diulang pada perubahan halaman informasi ini. Pengujian lama yang sudah berhasil tidak dijalankan ulang seluruhnya.

Dokumen kebijakan tidak menetapkan retensi tetap atau penghapusan otomatis yang belum diimplementasikan. Pengelola perlu memastikan isi halaman sesuai praktik produksi dan menindaklanjuti permintaan yang dikirim melalui kontak publik. Penilaian publikasi/brand tetap dilakukan Google.

## Referensi teknis

- Google: https://developers.google.com/identity/verification/authentication-verification
- Kebijakan data Google: https://developers.google.com/terms/api-services-user-data-policy
- Penyajian HTML statis dan fallback SPA Cloudflare: https://developers.cloudflare.com/pages/configuration/serving-pages/

Cloudflare Pages mendahulukan berkas HTML yang cocok dengan rute sebelum fallback SPA bawaan. Aturan redirect/rewrite khusus pada proyek pengguna belum tersedia untuk diperiksa; lihat panduan pemasangan jika halaman informasi malah diarahkan ke login.
