import 'package:flutter/foundation.dart';

class CharacterDefinition {
  const CharacterDefinition(
    this.id,
    this.title,
    this.family,
    this.gender, {
    this.enabled = true,
  });
  final String id, title, family, gender;
  final bool enabled;
}

/// Registry terbaru; berkas lama yang tersisa tidak menjadi pilihan karakter.
const characterDefinitions = <String, CharacterDefinition>{
  'pria-ahlipijat': CharacterDefinition(
    'pria-ahlipijat',
    'Ahli Pijat',
    'ahlipijat',
    'pria',
  ),
  'pria-ahlisauna': CharacterDefinition(
    'pria-ahlisauna',
    'Ahli Sauna',
    'ahlisauna',
    'pria',
  ),
  'pria-arsiparis': CharacterDefinition(
    'pria-arsiparis',
    'Arsiparis',
    'arsiparis',
    'pria',
  ),
  'pria-asistenperpustakaan': CharacterDefinition(
    'pria-asistenperpustakaan',
    'Asisten Perpustakaan',
    'asistenperpustakaan',
    'pria',
  ),
  'pria-dokter': CharacterDefinition('pria-dokter', 'Dokter', 'dokter', 'pria'),
  'pria-dokumentalis': CharacterDefinition(
    'pria-dokumentalis',
    'Dokumentalis',
    'dokumentalis',
    'pria',
  ),
  'pria-jurumasak': CharacterDefinition(
    'pria-jurumasak',
    'Juru Masak',
    'jurumasak',
    'pria',
  ),
  'pria-jurumasak2': CharacterDefinition(
    'pria-jurumasak2',
    'Juru Masak',
    'jurumasak',
    'pria',
  ),
  'pria-kesatria': CharacterDefinition(
    'pria-kesatria',
    'Kesatria',
    'kesatria',
    'pria',
  ),
  'pria-matamata': CharacterDefinition(
    'pria-matamata',
    'Mata-mata',
    'matamata',
    'pria',
  ),
  'pria-mediskolamrenang': CharacterDefinition(
    'pria-mediskolamrenang',
    'Medis Kolam Renang',
    'mediskolamrenang',
    'pria',
  ),
  'pria-medispantai': CharacterDefinition(
    'pria-medispantai',
    'Medis Pantai',
    'medispantai',
    'pria',
  ),
  'pria-medispantai2': CharacterDefinition(
    'pria-medispantai2',
    'Medis Pantai',
    'medispantai',
    'pria',
  ),
  'pria-modellukis': CharacterDefinition(
    'pria-modellukis',
    'Model Lukis',
    'modellukis',
    'pria',
  ),
  'pria-modellukis2': CharacterDefinition(
    'pria-modellukis2',
    'Model Lukis',
    'modellukis',
    'pria',
  ),
  'pria-modellukis3': CharacterDefinition(
    'pria-modellukis3',
    'Model Lukis',
    'modellukis',
    'pria',
  ),
  'pria-modellukis4': CharacterDefinition(
    'pria-modellukis4',
    'Model Lukis',
    'modellukis',
    'pria',
  ),
  'pria-nelayanbudidaya': CharacterDefinition(
    'pria-nelayanbudidaya',
    'Nelayan Budidaya',
    'nelayanbudidaya',
    'pria',
  ),
  'pria-nelayandemersal': CharacterDefinition(
    'pria-nelayandemersal',
    'Nelayan Demersal',
    'nelayandemersal',
    'pria',
  ),
  'pria-nelayandemersal2': CharacterDefinition(
    'pria-nelayandemersal2',
    'Nelayan Demersal',
    'nelayandemersal',
    'pria',
  ),
  'pria-nelayanpelagis': CharacterDefinition(
    'pria-nelayanpelagis',
    'Nelayan Pelagis',
    'nelayanpelagis',
    'pria',
  ),
  'pria-nelayanpelagis2': CharacterDefinition(
    'pria-nelayanpelagis2',
    'Nelayan Pelagis',
    'nelayanpelagis',
    'pria',
  ),
  'pria-nelayanpesisir': CharacterDefinition(
    'pria-nelayanpesisir',
    'Nelayan Pesisir',
    'nelayanpesisir',
    'pria',
  ),
  'pria-nelayanplasma': CharacterDefinition(
    'pria-nelayanplasma',
    'Nelayan Plasma',
    'nelayanplasma',
    'pria',
  ),
  'pria-nelayantambak': CharacterDefinition(
    'pria-nelayantambak',
    'Nelayan Tambak',
    'nelayantambak',
    'pria',
  ),
  'pria-olahragawan': CharacterDefinition(
    'pria-olahragawan',
    'Olahragawan',
    'olahragawan',
    'pria',
  ),
  'pria-pelajarrenang': CharacterDefinition(
    'pria-pelajarrenang',
    'Pelajar Renang',
    'pelajarrenang',
    'pria',
  ),
  'pria-pelajarselam': CharacterDefinition(
    'pria-pelajarselam',
    'Pelajar Selam',
    'pelajarselam',
    'pria',
  ),
  'pria-pelatihkebugaran': CharacterDefinition(
    'pria-pelatihkebugaran',
    'Pelatih Kebugaran',
    'pelatihkebugaran',
    'pria',
  ),
  'pria-pelatihpanahan': CharacterDefinition(
    'pria-pelatihpanahan',
    'Pelatih Panahan',
    'pelatihpanahan',
    'pria',
  ),
  'pria-pelatihrenang': CharacterDefinition(
    'pria-pelatihrenang',
    'Pelatih Renang',
    'pelatihrenang',
    'pria',
  ),
  'pria-pelatihselam': CharacterDefinition(
    'pria-pelatihselam',
    'Pelatih Selam',
    'pelatihselam',
    'pria',
  ),
  'pria-pelatihselancar': CharacterDefinition(
    'pria-pelatihselancar',
    'Pelatih Selancar',
    'pelatihselancar',
    'pria',
  ),
  'pria-pelatihselancar2': CharacterDefinition(
    'pria-pelatihselancar2',
    'Pelatih Selancar',
    'pelatihselancar',
    'pria',
  ),
  'pria-pelatihstrategi': CharacterDefinition(
    'pria-pelatihstrategi',
    'Pelatih Strategi',
    'pelatihstrategi',
    'pria',
  ),
  'pria-pelindung': CharacterDefinition(
    'pria-pelindung',
    'Pelindung',
    'pelindung',
    'pria',
  ),
  'pria-pemanah': CharacterDefinition(
    'pria-pemanah',
    'Pemanah',
    'pemanah',
    'pria',
  ),
  'pria-pembersihjalan': CharacterDefinition(
    'pria-pembersihjalan',
    'Pembersih Jalan',
    'pembersihjalan',
    'pria',
  ),
  'pria-pembersihpantai': CharacterDefinition(
    'pria-pembersihpantai',
    'Pembersih Pantai',
    'pembersihpantai',
    'pria',
  ),
  'pria-pembudidayaikanhias': CharacterDefinition(
    'pria-pembudidayaikanhias',
    'Pembudidaya Ikan Hias',
    'pembudidayaikanhias',
    'pria',
  ),
  'pria-pembudidayamutiara': CharacterDefinition(
    'pria-pembudidayamutiara',
    'Pembudidaya Mutiara',
    'pembudidayamutiara',
    'pria',
  ),
  'pria-pembudidayamutiara2': CharacterDefinition(
    'pria-pembudidayamutiara2',
    'Pembudidaya Mutiara',
    'pembudidayamutiara',
    'pria',
  ),
  'pria-pembudidayarumputlaut': CharacterDefinition(
    'pria-pembudidayarumputlaut',
    'Pembudidaya Rumput Laut',
    'pembudidayarumputlaut',
    'pria',
  ),
  'pria-pembudidayarumputlaut2': CharacterDefinition(
    'pria-pembudidayarumputlaut2',
    'Pembudidaya Rumput Laut',
    'pembudidayarumputlaut',
    'pria',
  ),
  'pria-pembudidayaudang': CharacterDefinition(
    'pria-pembudidayaudang',
    'Pembudidaya Udang',
    'pembudidayaudang',
    'pria',
  ),
  'pria-pemburu': CharacterDefinition(
    'pria-pemburu',
    'Pemburu',
    'pemburu',
    'pria',
  ),
  'pria-pemburubabihutan': CharacterDefinition(
    'pria-pemburubabihutan',
    'Pemburu Babi Hutan',
    'pemburubabihutan',
    'pria',
  ),
  'pria-pembururusa': CharacterDefinition(
    'pria-pembururusa',
    'Pemburu Rusa',
    'pembururusa',
    'pria',
  ),
  'pria-pemeriksamedis': CharacterDefinition(
    'pria-pemeriksamedis',
    'Pemeriksa Medis',
    'pemeriksamedis',
    'pria',
  ),
  'pria-pemetikbuah': CharacterDefinition(
    'pria-pemetikbuah',
    'Pemetik Buah',
    'pemetikbuah',
    'pria',
  ),
  'pria-pemetikbuah2': CharacterDefinition(
    'pria-pemetikbuah2',
    'Pemetik Buah',
    'pemetikbuah',
    'pria',
  ),
  'pria-penambakgaram': CharacterDefinition(
    'pria-penambakgaram',
    'Petambak Garam',
    'petambakgaram',
    'pria',
  ),
  'pria-penambangbatubara': CharacterDefinition(
    'pria-penambangbatubara',
    'Penambang Batu Bara',
    'penambangbatubara',
    'pria',
  ),
  'pria-penari': CharacterDefinition('pria-penari', 'Penari', 'penari', 'pria'),
  'pria-penarikerajaan': CharacterDefinition(
    'pria-penarikerajaan',
    'Penari Kerajaan',
    'penarikerajaan',
    'pria',
  ),
  'pria-penarimagis': CharacterDefinition(
    'pria-penarimagis',
    'Penari Magis',
    'penarimagis',
    'pria',
  ),
  'pria-penaritiang': CharacterDefinition(
    'pria-penaritiang',
    'Penari Tiang',
    'penaritiang',
    'pria',
  ),
  'pria-penatarias': CharacterDefinition(
    'pria-penatarias',
    'Penata Rias',
    'penatarias',
    'pria',
  ),
  'pria-penatu': CharacterDefinition('pria-penatu', 'Penatu', 'penatu', 'pria'),
  'pria-penebangkayu': CharacterDefinition(
    'pria-penebangkayu',
    'Penebang Kayu',
    'penebangkayu',
    'pria',
  ),
  'pria-penggoda': CharacterDefinition(
    'pria-penggoda',
    'Penggoda',
    'penggoda',
    'pria',
    enabled: false,
  ),
  'pria-penggoda1': CharacterDefinition(
    'pria-penggoda1',
    'Penggoda',
    'penggoda',
    'pria',
    enabled: false,
  ),
  'pria-penggoda2': CharacterDefinition(
    'pria-penggoda2',
    'Penggoda',
    'penggoda',
    'pria',
    enabled: false,
  ),
  'pria-penggoda3': CharacterDefinition(
    'pria-penggoda3',
    'Penggoda',
    'penggoda',
    'pria',
    enabled: false,
  ),
  'pria-penjagalaut': CharacterDefinition(
    'pria-penjagalaut',
    'Penjaga Laut',
    'penjagalaut',
    'pria',
  ),
  'pria-penjagamenarajaga': CharacterDefinition(
    'pria-penjagamenarajaga',
    'Penjaga Menara Jaga',
    'penjagamenarajaga',
    'pria',
  ),
  'pria-penjagamercusuar': CharacterDefinition(
    'pria-penjagamercusuar',
    'Penjaga Mercusuar',
    'penjagamercusuar',
    'pria',
  ),
  'pria-penjagapantai': CharacterDefinition(
    'pria-penjagapantai',
    'Penjaga Pantai',
    'penjagapantai',
    'pria',
  ),
  'pria-penjagapatroli': CharacterDefinition(
    'pria-penjagapatroli',
    'Penjaga Patroli',
    'penjagapatroli',
    'pria',
  ),
  'pria-penjagaperbatasan': CharacterDefinition(
    'pria-penjagaperbatasan',
    'Penjaga Perbatasan',
    'penjagaperbatasan',
    'pria',
  ),
  'pria-penjagaposjaga': CharacterDefinition(
    'pria-penjagaposjaga',
    'Penjaga Pos Jaga',
    'penjagaposjaga',
    'pria',
  ),
  'pria-penjagatokopantai': CharacterDefinition(
    'pria-penjagatokopantai',
    'Penjaga Toko Pantai',
    'penjagatokopantai',
    'pria',
  ),
  'pria-penjelajah': CharacterDefinition(
    'pria-penjelajah',
    'Penjelajah',
    'penjelajah',
    'pria',
  ),
  'pria-penyadapkaret': CharacterDefinition(
    'pria-penyadapkaret',
    'Penyadap Karet',
    'penyadapkaret',
    'pria',
  ),
  'pria-penyadapkaret2': CharacterDefinition(
    'pria-penyadapkaret2',
    'Penyadap Karet',
    'penyadapkaret',
    'pria',
  ),
  'pria-penyadapkaret3': CharacterDefinition(
    'pria-penyadapkaret3',
    'Penyadap Karet',
    'penyadapkaret',
    'pria',
  ),
  'pria-penyadapkaret4': CharacterDefinition(
    'pria-penyadapkaret4',
    'Penyadap Karet',
    'penyadapkaret',
    'pria',
  ),
  'pria-penyadapnira': CharacterDefinition(
    'pria-penyadapnira',
    'Penyadap Nira',
    'penyadapnira',
    'pria',
  ),
  'pria-penyadapnira2': CharacterDefinition(
    'pria-penyadapnira2',
    'Penyadap Nira',
    'penyadapnira',
    'pria',
  ),
  'pria-penyangraibijikakao': CharacterDefinition(
    'pria-penyangraibijikakao',
    'Penyangrai Biji Kakao',
    'penyangraibijikakao',
    'pria',
  ),
  'pria-penyangraibijikakao2': CharacterDefinition(
    'pria-penyangraibijikakao2',
    'Penyangrai Biji Kakao',
    'penyangraibijikakao',
    'pria',
  ),
  'pria-penyangraikopi': CharacterDefinition(
    'pria-penyangraikopi',
    'Penyangrai Kopi',
    'penyangraikopi',
    'pria',
  ),
  'pria-penyelam': CharacterDefinition(
    'pria-penyelam',
    'Penyelam',
    'penyelam',
    'pria',
  ),
  'pria-penyelamkeselamatan': CharacterDefinition(
    'pria-penyelamkeselamatan',
    'Penyelam Keselamatan',
    'penyelamkeselamatan',
    'pria',
  ),
  'pria-perakitkapal': CharacterDefinition(
    'pria-perakitkapal',
    'Perakit Kapal',
    'perakitkapal',
    'pria',
  ),
  'pria-perakitkapal2': CharacterDefinition(
    'pria-perakitkapal2',
    'Perakit Kapal',
    'perakitkapal',
    'pria',
  ),
  'pria-perakitsenjata': CharacterDefinition(
    'pria-perakitsenjata',
    'Perakit Senjata',
    'perakitsenjata',
    'pria',
  ),
  'pria-peramalcuaca': CharacterDefinition(
    'pria-peramalcuaca',
    'Peramal Cuaca',
    'peramalcuaca',
    'pria',
  ),
  'pria-peramalnasib': CharacterDefinition(
    'pria-peramalnasib',
    'Peramal Nasib',
    'peramalnasib',
    'pria',
  ),
  'pria-peramujamur': CharacterDefinition(
    'pria-peramujamur',
    'Peramu Jamur',
    'peramujamur',
    'pria',
  ),
  'pria-peramumadu': CharacterDefinition(
    'pria-peramumadu',
    'Peramu Madu',
    'peramumadu',
    'pria',
  ),
  'pria-perancangkapal': CharacterDefinition(
    'pria-perancangkapal',
    'Perancang Kapal',
    'perancangkapal',
    'pria',
  ),
  'pria-perawat': CharacterDefinition(
    'pria-perawat',
    'Perawat',
    'perawat',
    'pria',
  ),
  'pria-perenang': CharacterDefinition(
    'pria-perenang',
    'Perenang',
    'perenang',
    'pria',
  ),
  'pria-peselancar': CharacterDefinition(
    'pria-peselancar',
    'Peselancar',
    'peselancar',
    'pria',
  ),
  'pria-petambakgaram': CharacterDefinition(
    'pria-petambakgaram',
    'Petambak Garam',
    'petambakgaram',
    'pria',
  ),
  'pria-petanidesa': CharacterDefinition(
    'pria-petanidesa',
    'Petani Desa',
    'petanidesa',
    'pria',
  ),
  'pria-petanihortikultura': CharacterDefinition(
    'pria-petanihortikultura',
    'Petani Hortikultura',
    'petanihortikultura',
    'pria',
  ),
  'pria-petanijagung': CharacterDefinition(
    'pria-petanijagung',
    'Petani Jagung',
    'petanijagung',
    'pria',
  ),
  'pria-petanikedelai': CharacterDefinition(
    'pria-petanikedelai',
    'Petani Kedelai',
    'petanikedelai',
    'pria',
  ),
  'pria-petanikedelai2': CharacterDefinition(
    'pria-petanikedelai2',
    'Petani Kedelai',
    'petanikedelai',
    'pria',
  ),
  'pria-petanipadi': CharacterDefinition(
    'pria-petanipadi',
    'Petani Padi',
    'petanipadi',
    'pria',
  ),
  'pria-petanipadi2': CharacterDefinition(
    'pria-petanipadi2',
    'Petani Padi',
    'petanipadi',
    'pria',
  ),
  'pria-petanipalawija': CharacterDefinition(
    'pria-petanipalawija',
    'Petani Palawija',
    'petanipalawija',
    'pria',
  ),
  'pria-peternakbibit': CharacterDefinition(
    'pria-peternakbibit',
    'Peternak Bibit',
    'peternakbibit',
    'pria',
  ),
  'pria-peternakbibit2': CharacterDefinition(
    'pria-peternakbibit2',
    'Peternak Bibit',
    'peternakbibit',
    'pria',
  ),
  'pria-peternakpedaging': CharacterDefinition(
    'pria-peternakpedaging',
    'Peternak Pedaging',
    'peternakpedaging',
    'pria',
  ),
  'pria-peternakperah': CharacterDefinition(
    'pria-peternakperah',
    'Peternak Perah',
    'peternakperah',
    'pria',
  ),
  'pria-peternakperah2': CharacterDefinition(
    'pria-peternakperah2',
    'Peternak Perah',
    'peternakperah',
    'pria',
  ),
  'pria-peternaktelur': CharacterDefinition(
    'pria-peternaktelur',
    'Peternak Telur',
    'peternaktelur',
    'pria',
  ),
  'pria-petuadesa': CharacterDefinition(
    'pria-petuadesa',
    'Petua Desa',
    'petuadesa',
    'pria',
  ),
  'pria-pramusaji': CharacterDefinition(
    'pria-pramusaji',
    'Pramusaji',
    'pramusaji',
    'pria',
  ),
  'pria-pustakawan': CharacterDefinition(
    'pria-pustakawan',
    'Pustakawan',
    'pustakawan',
    'pria',
  ),
  'pria-tukang': CharacterDefinition('pria-tukang', 'Tukang', 'tukang', 'pria'),
  'pria-tukangdrainase': CharacterDefinition(
    'pria-tukangdrainase',
    'Tukang Drainase',
    'tukangdrainase',
    'pria',
  ),
  'pria-tukanggerobak': CharacterDefinition(
    'pria-tukanggerobak',
    'Tukang Gerobak',
    'tukanggerobak',
    'pria',
  ),
  'pria-tukangmercusuar': CharacterDefinition(
    'pria-tukangmercusuar',
    'Tukang Mercusuar',
    'tukangmercusuar',
    'pria',
  ),
  'wanita-dokumentalis': CharacterDefinition(
    'wanita-dokumentalis',
    'Dokumentalis',
    'dokumentalis',
    'wanita',
  ),
  'wanita-matamata': CharacterDefinition(
    'wanita-matamata',
    'Mata-mata',
    'matamata',
    'wanita',
  ),
  'wanita-modellukis': CharacterDefinition(
    'wanita-modellukis',
    'Model Lukis',
    'modellukis',
    'wanita',
  ),
  'wanita-nelayanbudidaya': CharacterDefinition(
    'wanita-nelayanbudidaya',
    'Nelayan Budidaya',
    'nelayanbudidaya',
    'wanita',
  ),
  'wanita-pemanah': CharacterDefinition(
    'wanita-pemanah',
    'Pemanah',
    'pemanah',
    'wanita',
  ),
  'wanita-pemburu': CharacterDefinition(
    'wanita-pemburu',
    'Pemburu',
    'pemburu',
    'wanita',
  ),
  'wanita-pemburu2': CharacterDefinition(
    'wanita-pemburu2',
    'Pemburu',
    'pemburu',
    'wanita',
  ),
  'wanita-penari': CharacterDefinition(
    'wanita-penari',
    'Penari',
    'penari',
    'wanita',
  ),
  'wanita-penarikerajaan': CharacterDefinition(
    'wanita-penarikerajaan',
    'Penari Kerajaan',
    'penarikerajaan',
    'wanita',
  ),
  'wanita-penarimagis': CharacterDefinition(
    'wanita-penarimagis',
    'Penari Magis',
    'penarimagis',
    'wanita',
  ),
  'wanita-penatu': CharacterDefinition(
    'wanita-penatu',
    'Penatu',
    'penatu',
    'wanita',
  ),
  'wanita-penjagalaut': CharacterDefinition(
    'wanita-penjagalaut',
    'Penjaga Laut',
    'penjagalaut',
    'wanita',
  ),
  'wanita-penjagamenarajaga': CharacterDefinition(
    'wanita-penjagamenarajaga',
    'Penjaga Menara Jaga',
    'penjagamenarajaga',
    'wanita',
  ),
  'wanita-penjelajah': CharacterDefinition(
    'wanita-penjelajah',
    'Penjelajah',
    'penjelajah',
    'wanita',
  ),
  'wanita-penyadapkaret': CharacterDefinition(
    'wanita-penyadapkaret',
    'Penyadap Karet',
    'penyadapkaret',
    'wanita',
  ),
  'wanita-penyangraibijikakao': CharacterDefinition(
    'wanita-penyangraibijikakao',
    'Penyangrai Biji Kakao',
    'penyangraibijikakao',
    'wanita',
  ),
  'wanita-penyelam': CharacterDefinition(
    'wanita-penyelam',
    'Penyelam',
    'penyelam',
    'wanita',
  ),
  'wanita-perakitsenjata': CharacterDefinition(
    'wanita-perakitsenjata',
    'Perakit Senjata',
    'perakitsenjata',
    'wanita',
  ),
  'wanita-perenang': CharacterDefinition(
    'wanita-perenang',
    'Perenang',
    'perenang',
    'wanita',
  ),
  'wanita-peselancar': CharacterDefinition(
    'wanita-peselancar',
    'Peselancar',
    'peselancar',
    'wanita',
  ),
  'wanita-petanipadi': CharacterDefinition(
    'wanita-petanipadi',
    'Petani Padi',
    'petanipadi',
    'wanita',
  ),
  'wanita-peternaktelur': CharacterDefinition(
    'wanita-peternaktelur',
    'Peternak Telur',
    'peternaktelur',
    'wanita',
  ),
  'wanita-pramusaji': CharacterDefinition(
    'wanita-pramusaji',
    'Pramusaji',
    'pramusaji',
    'wanita',
  ),
  'wanita-pustakawan': CharacterDefinition(
    'wanita-pustakawan',
    'Pustakawan',
    'pustakawan',
    'wanita',
  ),
};

class CharacterCatalog {
  CharacterCatalog._();
  static final revision = ValueNotifier<int>(0);
  static Map<String, ({bool enabled, bool listed})> _remote = {};
  static bool _hasRemote = false;

  static bool isListed(String id) =>
      characterDefinitions.containsKey(id) &&
      (_hasRemote ? (_remote[id]?.listed ?? false) : true);
  static bool isEnabled(String id) =>
      isListed(id) &&
      (_hasRemote
          ? (_remote[id]?.enabled ?? false)
          : characterDefinitions[id]!.enabled);

  @visibleForTesting
  static void resetForTesting() {
    _hasRemote = false;
    _remote = {};
    revision.value++;
  }

  static void replaceStatus(Iterable<Map<String, dynamic>> rows) {
    final next = <String, ({bool enabled, bool listed})>{};
    for (final row in rows) {
      final id = row['id'];
      if (id is String && characterDefinitions.containsKey(id)) {
        next[id] = (
          enabled: row['enabled'] == true,
          listed: row['listed'] != false,
        );
      }
    }
    if (_hasRemote && mapEquals(_remote, next)) return;
    _hasRemote = true;
    _remote = next;
    revision.value++;
  }
}
