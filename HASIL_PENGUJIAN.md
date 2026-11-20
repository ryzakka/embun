# Validasi avatar akun / inisial tamu

20 November 2026. Flutter 3.38.10 / Dart 3.10.9.

| Pemeriksaan pada pembaruan ini | Hasil |
| --- | --- |
| Inisial, avatar terhubung, lobi, chat lobi/aktif, ending daftar/peringkat/gelar | 9 tes baru lulus |
| Regresi tamu, penautan, sesi, profil pribadi/publik, gelar dan riwayat | 27 tes lulus |
| Database lokal melalui PGlite 0.5.17 | 74 pengecekan lulus: 64 regresi dan 10 pemeriksaan avatar |
| Analisis komponen/model avatar, profil, waiting room, final screen dan tes baru | No issues found |
| Analisis integrasi lobby/table/chat | Tidak ada error; warning/info lama tersisa pada helper UI |
| Build web pratinjau akun | Berhasil, 31,1 detik |

Tes membuktikan avatar tamu mengabaikan ID gambar profil dan memakai inisial,
sedangkan akun Google merender avatar pilihan dengan penanda G. Pada lobi,
potret kartu tidak dipakai sebagai avatar daftar pemain; pemilihan karakter
tetap merupakan tindakan tersendiri. Mengetuk avatar membuka ID pemain yang tepat.

Chat lobi memakai avatar akun/inisial. Chat selama bermain tetap memakai potret
karakter, bahkan saat tes sengaja memberikan data akun pada widget chat aktif.
Ending memisahkan nama akun/pemain dari nama karakter; peringkat dan gelar juga
menggunakan avatar akun/inisial. Layout lobi diuji pada lebar 320 piksel.

Tes SQL memeriksa pemilihan avatar Google, nama asli tamu dari player_usernames,
payload yang hanya berisi user_id, google_linked, nickname dan avatar_id, penolakan
pemain luar/ruangan aktif, serta migrasi ulang tanpa menambah hitungan hasil.
Data akun berasal dari server, bukan tebakan berdasarkan kartu karakter.

Tidak dilakukan deployment, perubahan Supabase produksi atau multiplayer nyata.
Build yang berhasil adalah pratinjau akun, bukan build seluruh arsip gim yang
memiliki ketidakcocokan berkas suasana desa/malam yang sudah diketahui sebelumnya.

Untuk menjalankan tes SQL, letakkan verification/avatar_sql_test.mjs pada folder
Node yang memiliki @electric-sql/pglite@0.5.17 dan jalankan dengan tiga argumen:

```sh
node avatar_sql_test.mjs /jalur/20261120120000_profil_pemain.sql /jalur/20261120160000_tamu_google.sql /jalur/20261120180000_avatar_akun.sql
```

Database tes berada dalam memori dan memakai schema fixture. Tidak menggunakan
data atau kredensial Supabase produksi.
