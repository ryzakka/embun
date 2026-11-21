/// Nama berkas ikon terbaru dalam assets/ikon (tanpa ekstensi).
/// Ikon mendukung PNG/WebP; judul dan cap juga ditemukan di foldernya.
const embunIconNames = <String>{
  'addmember','akhir-kalah','akhir-menang','alert','announcement','back','back2',
  'barter','baru','botollab','bubarkan','bukatautan','bulansabit','bulirembun',
  'bulirhitam','centang','change','character','customization','danger','dibeli',
  'dipilih','discuss','donations','endday','hapusdata','hari','hatikosong',
  'hatipenuh','helaidaun','hide','home','host','identity','info','item','jampasir',
  'joinroom','jointoroom','kalah','keluar','kirim','lewatiakhir','lewatisatu',
  'lihatprofil','lock','logorhistory','matahari','medali','menang','menu','minus',
  'mydeck','mydeck2','notification','off','on','perbaikan','persona','pesanatauemail',
  'piala','plus','poinmin1','poinplus1','question','refresh','roomcode','roomcreate',
  'salin','samadengan','settings','show','showaddgraphic','silang','simpan','skip',
  'skip2','start','store','suaramati','suaranyala','takterbatas','tautan','tertuduh',
  'timer','titlemusyawarah','titlepasarriset','titlepersembahan','touch','ubah',
  'unduh','vote','wait','x','persen',
};

/// Kompatibilitas dengan ejaan dalam halaman lama.
const embunIconAliases = <String,String>{
  'title-musyawarah':'titlemusyawarah',
  'title-pasarriset':'titlepasarriset',
  'titlepasarrise':'titlepasarriset',
  'tutor':'touch',
  'pesanataumail':'pesanatauemail',
};
const _compatibleIcons = <String,List<String>>{
  'titlemusyawarah':['title-musyawarah'],
  'titlepasarriset':['title-pasarriset','titlepasarrise'],
  'touch':['tutor'],
  'back2':['back'],
  'jampasir':['wait'],
  'lihatprofil':['identity','persona'],
  'medali':['piala'],
  'piala':['medali'],
  'perbaikan':['settings'],
};
String canonicalIconName(String name) {
  final clean = name.trim().toLowerCase().replaceFirst(RegExp(r'\.(png|webp)$'),'');
  return embunIconAliases[clean] ?? clean;
}
Iterable<String> iconCandidates(String name) sync* {
  final canonical=canonicalIconName(name);
  yield canonical;
  yield* _compatibleIcons[canonical] ?? const <String>[];
}
