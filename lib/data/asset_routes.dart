import 'theme_catalog.dart';

const themedAssetRoots = <String, String>{
  'assets/kartu/CharPro/CharPro-Pria': 'assets/kartu/Char/CharPro/CharProDefault/CharPro-Pria',
  'assets/kartu/CharPro/CharPro-Wanita': 'assets/kartu/Char/CharPro/CharProDefault/CharPro-Wanita',
  'assets/kartu/CharProManhwaEdition': 'assets/kartu/Char/CharPro/CharProManhwaEdition',
  'assets/kartu/CharAnta': 'assets/kartu/Char/CharAnta/CharAnta',
  'assets/kartu/CharPopUp': 'assets/kartu/Char/CharPopUp/CharPopUp',
  'assets/kartu/punggungkartu': 'assets/kartu/BackCard/BackCard',
  'assets/kartu/itemPerawatan': 'assets/kartu/ItemCard/ItemCardPerawatan/ItemCardPerawatan',
  'assets/kartu/ItemPro': 'assets/kartu/ItemCard/ItemCardPro/ItemPro/ItemPro',
  'assets/kartu/ItemProDay': 'assets/kartu/ItemCard/ItemCardPro/ItemProDay/ItemProDay',
  'assets/kartu/ItemProRegenerasi': 'assets/kartu/ItemCard/ItemCardPro/ItemProRegenerasi/ItemProRegenerasi',
  'assets/kartu/CharSkill': 'assets/kartu/ItemCard/ItemCardPro/ItemCharProSkill/ItemCharProSkill',
  'assets/kartu/ItemAnta': 'assets/kartu/ItemCard/ItemCardAnta/ItemAnta/ItemAnta',
  'assets/kartu/ItemAntaNight': 'assets/kartu/ItemCard/ItemCardAnta/ItemAntaNight/ItemAntaNight',
  'assets/kartu/ItemAntaRekayasa': 'assets/kartu/ItemCard/ItemCardAnta/ItemAntaRekayasa/ItemAntaRekayasa',
};

Iterable<String> assetFolders(String folder, String theme) sync* {
  if (folder == 'assets/pohon') {
    final suffix = theme == tiongkokTheme ? 'lukisantiongkok'
        : theme == manhwaTheme ? 'manhwaedition' : 'default';
    yield 'assets/pohon/pohon$suffix';
    if (suffix != 'default') yield 'assets/pohon/pohondefault';
  } else {
    final root = themedAssetRoots[folder];
    if (root != null) {
      if (folder.contains('CharPro')) {
        yield root;
      } else {
        final suffix = theme == tiongkokTheme ? 'LukisanTiongkok'
            : theme == manhwaTheme ? 'ManhwaEdition' : 'Default';
        yield '$root$suffix';
        if (suffix != 'Default') yield '${root}Default';
      }
    }
  }
  yield folder; // Older installs remain readable during a merge.
}

const assetStemAliases = <String, String>{
  'airsuci': 'airsuci1',
  'daunembun': 'daunembun1',
  'wanita-penyangraibijikakao': 'wanita-penyangraibijikako',
  'junghyunwoo-kemejabiruabu': 'junghyunwoo-kemejabiruabuabu',
  'kwontaehyuk-kasualtaskiri': 'kwontaehyuk-kaoskasualtaskiri',
  'pesanataumail': 'pesanatauemail',
  'kemampuan1': 'simatasuci',
  'mata_suci': 'simatasuci',
  'kemampuan2': 'kamerarekaan',
  'kamera_rekaan': 'kamerarekaan',
  'kemampuan3': 'arlojikhayal',
  'arloji_khayal': 'arlojikhayal',
  'kemampuan4': 'jemarimagis',
  'jemari_magis': 'jemarimagis',
  'kemampuan5': 'kebangkitan',
  'kebangkitan_arwah': 'kebangkitan',
  'kemampuan6': 'patuhlah',
  'palu_hakim': 'patuhlah',
  'kemampuan7': 'orangbiasa',
  'biasa': 'orangbiasa',
  'kemampuan8': 'janganbohong',
  'jangan_bohong': 'janganbohong',
  'kemampuan9': 'tumbuhanituaku',
  'tumbuhan': 'tumbuhanituaku',
  'kemampuan10': 'pedagangulung',
  'pedagang': 'pedagangulung',
  'kemampuan11': 'lidahmanis',
  'lidah_manis': 'lidahmanis',
  'kemampuan12': 'kuncisegel',
  'kunci_segel': 'kuncisegel',
  'kemampuan13': 'buktituduhan',
  'buktikan_tuduhan': 'buktituduhan',
  'kemampuan14': 'sidangterbuka',
  'sidang_terbuka': 'sidangterbuka',
  'kemampuan15': 'penanggungluka',
  'penanggung_luka': 'penanggungluka',
  'kemampuan16': 'pembacaniat',
  'pembaca_niat': 'pembacaniat',
  'kemampuan17': 'kotaksuara',
  'warisan_suara': 'kotaksuara',
};
