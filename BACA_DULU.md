# Embun — Avatar akun dan inisial tamu

Paket melanjutkan UI terbaru dan dukungan tamu/Google sebelumnya. Avatar akun
dipakai untuk identitas sosial di luar pertandingan, sedangkan potret karakter
tetap menjadi identitas selama permainan.

## Pasang

1. Cadangkan proyek. Gabungkan seluruh folder **lib/** dan **web/** dalam paket
   ke proyek Flutter. Timpa berkas yang sama, tanpa menghapus berkas lain.
2. Di Supabase SQL Editor, jalankan **20261120180000_avatar_akun.sql**. Bila dua
   migrasi profil/tamu sebelumnya sudah dipasang, cukup SQL tambahan ini.
   Untuk pemasangan pertama, jalankan berurutan:
   - 20261120120000_profil_pemain.sql
   - 20261120160000_tamu_google.sql
   - 20261120180000_avatar_akun.sql
   Jangan menjalankan ulang migrasi lama sendirian sesudah migrasi baru.
3. Avatar PNG atau WebP tetap berada di assets/avatars/, dengan nama dasar yang
   sama dan entri assets/avatars/ di pubspec.yaml. Jika dua format tersedia,
   WebP diutamakan. Tidak ada gambar baru yang perlu dipasang.
4. Build dan deploy aplikasi seperti biasa. Entry point produksi tetap
   lib/main.dart. Tidak memerlukan perubahan Google Cloud atau pengaturan Auth
   baru jika mode tamu dan penautan Google sebelumnya sudah berfungsi.

SQL baru diperlukan untuk mengirim nama/avatar akun sesama peserta secara
terbatas. Payload tidak menyertakan email, statistik, permintaan penghapusan,
atau rahasia permainan. Tidak ada RPC permainan yang diganti dan tidak ada
perubahan pada pencatatan statistik. Supabase produksi belum diubah oleh paket.

## Hasil tampilan

| Lokasi | Avatar yang dipakai |
| --- | --- |
| Menu utama | Avatar akun Google; tamu memakai inisial nama yang sedang diketahui |
| Daftar pemain lobi | Avatar akun atau inisial tamu, dapat diketuk untuk informasi pemain |
| Chat lobi | Avatar akun atau inisial pengirim di samping kelompok pesan |
| Profil pribadi/pemain | Avatar akun besar; rincian tamu memakai inisial dan keterangan belum menautkan Google |
| Ending, daftar pemain dan catatan rinci | Avatar akun/inisial, nama pemain dan karakter ditampilkan terpisah |
| Ending, peringkat dan gelar | Avatar akun/inisial penerima penghargaan |
| Selama bermain, musyawarah dan chat pertandingan | Potret karakter tetap dipakai untuk menjaga penyamaran |

Kartu besar/sinematik pengungkapan peran tetap menggambarkan karakter. Pilihan
karakter di lobi masih tersedia melalui tombol ganti karakter, beserta nama
karakter yang dipilih. Avatar akun tidak menggantikan kartu permainan.

## Inisial tamu

- Budi Santoso → **BS**.
- Budi Agus Santoso → **BS**.
- Ayu → **A**.
- Sebelum nama ruangan diisi, menu tamu memakai **T** untuk Tamu.
- Nama yang benar-benar tidak tersedia memakai tanda **?**.

Avatar tamu berupa huruf pada lingkaran, tanpa gambar profil atau ikon orang.
Tamu tidak mendapat profil akun tersimpan. Ikon G kecil hanya muncul pada avatar
akun yang terhubung ke Google. Jika status belum diketahui, aplikasi tidak
menebaknya sebagai tamu dan tidak memberi penanda Google.

Saat ending, inisial tamu diambil dari nama pemain sebelum penyamaran, sehingga
tetap BS walaupun selama permainan ia memakai nama karakter Peternak Telur.

## Batas akses

Nama dan avatar akun pemain lain hanya dikirim bagi sesama peserta ruangan saat
status lobi atau selesai. Server menolak daftar avatar selama permainan berjalan
dan bagi pemain luar. Chat aktif memakai potret karakter walaupun caller tanpa
sengaja menyertakan data avatar akun. Tujuannya menjaga identitas tersamar.

Mode tamu, penautan Google, login ke akun lama, profil, gelar, statistik, riwayat,
dan permintaan penghapusan tetap mengikuti paket sebelumnya. Pertandingan tamu
tidak dipindahkan ke riwayat akun setelah menautkan Google.

## Validasi

Lihat HASIL_PENGUJIAN.md. Sembilan tes baru, 27 regresi profil/tamu, dan 74
pengecekan PostgreSQL lokal lulus. Build web pratinjau akun berhasil.

Pratinjau akun lokal tersedia melalui:

```sh
flutter run -d chrome -t lib/account_preview_main.dart
```

Pratinjau tersebut memakai data contoh dalam memori dan bertanda PRATINJAU
LOKAL. Jangan deploy target pratinjau sebagai aplikasi produksi.
