/// Bundled avatars; all choices are available, with no unlock system.
const profileAvatars = <String, (String, String)>{
  'penjaga_hayu': ('01_penjaga_hayu.png', 'Penjaga Hayu'),
  'peramu_bunga': ('02_peramu_bunga.png', 'Peramu Bunga'),
  'petani_muda': ('03_petani_muda.png', 'Petani Muda'),
  'pengelana_rimba': ('04_pengelana_rimba.png', 'Pengelana Rimba'),
  'jurutulis_desa': ('05_jurutulis_desa.png', 'Jurutulis Desa'),
  'penenun_daun': ('06_penenun_daun.png', 'Penenun Daun'),
  'penjaga_sumur': ('07_penjaga_sumur.png', 'Penjaga Sumur'),
  'perawat_desa': ('08_perawat_desa.png', 'Perawat Desa'),
  'perajin_kayu': ('09_perajin_kayu.png', 'Perajin Kayu'),
  'tetua_bijak': ('10_tetua_bijak.png', 'Tetua Bijak'),
};

// Older saved icon preferences remain valid until the owner picks a PNG.
const legacyProfileAvatarIds = [
  'leaf',
  'sun',
  'moon',
  'water',
  'flower',
  'tree',
];
final profileAvatarIds = [...profileAvatars.keys, ...legacyProfileAvatarIds];
