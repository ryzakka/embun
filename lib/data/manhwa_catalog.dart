const manhwaDir = 'assets/kartu/CharProManhwaEdition';
const manhwaTheme = 'manhwa';
const defaultTheme = 'default';

class ManhwaOutfit {
  const ManhwaOutfit(this.id, this.characterId, this.label);
  final String id, characterId, label;
}

const manhwaNames = <String, String>{
  "arystanbeknurlanuly": "Arystanbek Nurlanuly",
  "baekseoyeon": "Baek Seo-yeon",
  "chahyunjae": "Cha Hyun-jae",
  "chaminhyuk": "Cha Min-hyuk",
  "choinari": "Choi Na-ri",
  "fujiwaraaoi": "Fujiwara Aoi",
  "hanseoah": "Han Seo-ah",
  "hanseoyul": "Han Seo-yul",
  "junghyunwoo": "Jung Hyun-woo",
  "kangjiwoo": "Kang Ji-woo",
  "kimdasol": "Kim Da-sol",
  "kurokawaren": "Kurokawa Ren",
  "kwontaehyuk": "Kwon Tae-hyuk",
  "leejunseo": "Lee Jun-seo",
  "linzixuan": "Lin Zixuan",
  "namseojun": "Nam Seo-jun",
  "suqinghuan": "Su Qinghuan",
  "xuwenjing": "Xu Wenjing",
  "zhangmingzhe": "Zhang Mingzhe",
};

const manhwaOutfits = <String, ManhwaOutfit>{
  "arystanbeknurlanuly-utama": ManhwaOutfit(
    "arystanbeknurlanuly-utama",
    "arystanbeknurlanuly",
    "Kartu utama",
  ),
  "arystanbeknurlanuly-berkuda": ManhwaOutfit(
    "arystanbeknurlanuly-berkuda",
    "arystanbeknurlanuly",
    "Berkuda",
  ),
  "arystanbeknurlanuly-kaoskampus": ManhwaOutfit(
    "arystanbeknurlanuly-kaoskampus",
    "arystanbeknurlanuly",
    "Kaos kampus",
  ),
  "arystanbeknurlanuly-kaosolahraga": ManhwaOutfit(
    "arystanbeknurlanuly-kaosolahraga",
    "arystanbeknurlanuly",
    "Kaos olahraga",
  ),
  "arystanbeknurlanuly-kemejahitam": ManhwaOutfit(
    "arystanbeknurlanuly-kemejahitam",
    "arystanbeknurlanuly",
    "Kemeja hitam",
  ),
  "baekseoyeon-utama": ManhwaOutfit(
    "baekseoyeon-utama",
    "baekseoyeon",
    "Kartu utama",
  ),
  "baekseoyeon-kaoshitamtamanponsel": ManhwaOutfit(
    "baekseoyeon-kaoshitamtamanponsel",
    "baekseoyeon",
    "Kaos hitam · taman",
  ),
  "baekseoyeon-sweeterhitamkafeminum": ManhwaOutfit(
    "baekseoyeon-sweeterhitamkafeminum",
    "baekseoyeon",
    "Sweter hitam · kafe",
  ),
  "chahyunjae-utama": ManhwaOutfit(
    "chahyunjae-utama",
    "chahyunjae",
    "Kartu utama",
  ),
  "chahyunjae-basketkaosbasah": ManhwaOutfit(
    "chahyunjae-basketkaosbasah",
    "chahyunjae",
    "Pakaian basket",
  ),
  "chahyunjae-internetkafesweetermerah": ManhwaOutfit(
    "chahyunjae-internetkafesweetermerah",
    "chahyunjae",
    "Sweter merah · kafe",
  ),
  "chahyunjae-jaketbasket": ManhwaOutfit(
    "chahyunjae-jaketbasket",
    "chahyunjae",
    "Jaket basket",
  ),
  "chaminhyuk-utama": ManhwaOutfit(
    "chaminhyuk-utama",
    "chaminhyuk",
    "Kartu utama",
  ),
  "chaminhyuk-gamerpink": ManhwaOutfit(
    "chaminhyuk-gamerpink",
    "chaminhyuk",
    "Hoodie pink · gaming",
  ),
  "chaminhyuk-jaketbirutua": ManhwaOutfit(
    "chaminhyuk-jaketbirutua",
    "chaminhyuk",
    "Jaket biru tua",
  ),
  "chaminhyuk-kaostanpalengan": ManhwaOutfit(
    "chaminhyuk-kaostanpalengan",
    "chaminhyuk",
    "Kaos tanpa lengan",
  ),
  "chaminhyuk-kemejabiru": ManhwaOutfit(
    "chaminhyuk-kemejabiru",
    "chaminhyuk",
    "Kemeja biru",
  ),
  "chaminhyuk-lari": ManhwaOutfit(
    "chaminhyuk-lari",
    "chaminhyuk",
    "Pakaian lari",
  ),
  "chaminhyuk-renang": ManhwaOutfit(
    "chaminhyuk-renang",
    "chaminhyuk",
    "Pakaian renang",
  ),
  "chaminhyuk-sweeterhijau": ManhwaOutfit(
    "chaminhyuk-sweeterhijau",
    "chaminhyuk",
    "Sweter hijau",
  ),
  "chaminhyuk-trainingabu": ManhwaOutfit(
    "chaminhyuk-trainingabu",
    "chaminhyuk",
    "Training abu-abu",
  ),
  "choinari-utama": ManhwaOutfit("choinari-utama", "choinari", "Kartu utama"),
  "choinari-belanjagenit": ManhwaOutfit(
    "choinari-belanjagenit",
    "choinari",
    "Pakaian belanja",
  ),
  "choinari-kelasseragam": ManhwaOutfit(
    "choinari-kelasseragam",
    "choinari",
    "Seragam kampus",
  ),
  "choinari-pinktaskecil": ManhwaOutfit(
    "choinari-pinktaskecil",
    "choinari",
    "Pink · tas kecil",
  ),
  "choinari-putihpita": ManhwaOutfit(
    "choinari-putihpita",
    "choinari",
    "Blus putih berpita",
  ),
  "choinari-ungu": ManhwaOutfit("choinari-ungu", "choinari", "Sweter lavender"),
  "fujiwaraaoi-utama": ManhwaOutfit(
    "fujiwaraaoi-utama",
    "fujiwaraaoi",
    "Kartu utama",
  ),
  "fujiwaraaoi-bajutradisional": ManhwaOutfit(
    "fujiwaraaoi-bajutradisional",
    "fujiwaraaoi",
    "Pakaian tradisional",
  ),
  "fujiwaraaoi-seragamkampus": ManhwaOutfit(
    "fujiwaraaoi-seragamkampus",
    "fujiwaraaoi",
    "Seragam kampus",
  ),
  "hanseoah-utama": ManhwaOutfit("hanseoah-utama", "hanseoah", "Kartu utama"),
  "hanseoah-bubblebajupink": ManhwaOutfit(
    "hanseoah-bubblebajupink",
    "hanseoah",
    "Blus pink",
  ),
  "hanseoah-eleganputih": ManhwaOutfit(
    "hanseoah-eleganputih",
    "hanseoah",
    "Blus putih",
  ),
  "hanseoah-kaosputihponsel": ManhwaOutfit(
    "hanseoah-kaosputihponsel",
    "hanseoah",
    "Kaos putih · ponsel",
  ),
  "hanseoah-lari": ManhwaOutfit("hanseoah-lari", "hanseoah", "Pakaian lari"),
  "hanseoah-laritrek": ManhwaOutfit(
    "hanseoah-laritrek",
    "hanseoah",
    "Olahraga hitam",
  ),
  "hanseoah-pinkminum": ManhwaOutfit(
    "hanseoah-pinkminum",
    "hanseoah",
    "Sweter pink · tumbler",
  ),
  "hanseoyul-utama": ManhwaOutfit(
    "hanseoyul-utama",
    "hanseoyul",
    "Kartu utama",
  ),
  "hanseoyul-gym": ManhwaOutfit("hanseoyul-gym", "hanseoyul", "Pakaian gym"),
  "hanseoyul-kasualkaoskrem": ManhwaOutfit(
    "hanseoyul-kasualkaoskrem",
    "hanseoyul",
    "Kaos krem",
  ),
  "hanseoyul-minimarketsweeterhitam": ManhwaOutfit(
    "hanseoyul-minimarketsweeterhitam",
    "hanseoyul",
    "Sweter hitam · minimarket",
  ),
  "hanseoyul-renang": ManhwaOutfit(
    "hanseoyul-renang",
    "hanseoyul",
    "Pakaian renang",
  ),
  "hanseoyul-sweeterhitamminum": ManhwaOutfit(
    "hanseoyul-sweeterhitamminum",
    "hanseoyul",
    "Sweter hitam",
  ),
  "junghyunwoo-utama": ManhwaOutfit(
    "junghyunwoo-utama",
    "junghyunwoo",
    "Kartu utama",
  ),
  "junghyunwoo-basket": ManhwaOutfit(
    "junghyunwoo-basket",
    "junghyunwoo",
    "Pakaian basket",
  ),
  "junghyunwoo-gym": ManhwaOutfit(
    "junghyunwoo-gym",
    "junghyunwoo",
    "Pakaian gym",
  ),
  "junghyunwoo-kemejabiruabu": ManhwaOutfit(
    "junghyunwoo-kemejabiruabu",
    "junghyunwoo",
    "Kemeja biru abu-abu",
  ),
  "junghyunwoo-kemejakampus": ManhwaOutfit(
    "junghyunwoo-kemejakampus",
    "junghyunwoo",
    "Kemeja kampus",
  ),
  "kangjiwoo-utama": ManhwaOutfit(
    "kangjiwoo-utama",
    "kangjiwoo",
    "Kartu utama",
  ),
  "kangjiwoo-gamerkaosputih": ManhwaOutfit(
    "kangjiwoo-gamerkaosputih",
    "kangjiwoo",
    "Kaos putih · gaming",
  ),
  "kangjiwoo-lari": ManhwaOutfit("kangjiwoo-lari", "kangjiwoo", "Pakaian lari"),
  "kangjiwoo-sweeterhitamkafe": ManhwaOutfit(
    "kangjiwoo-sweeterhitamkafe",
    "kangjiwoo",
    "Sweter hitam · kafe",
  ),
  "kimdasol-utama": ManhwaOutfit("kimdasol-utama", "kimdasol", "Kartu utama"),
  "kimdasol-jaketbirukuning": ManhwaOutfit(
    "kimdasol-jaketbirukuning",
    "kimdasol",
    "Jaket biru-kuning",
  ),
  "kimdasol-kampuskasual": ManhwaOutfit(
    "kimdasol-kampuskasual",
    "kimdasol",
    "Kasual · kampus",
  ),
  "kurokawaren-utama": ManhwaOutfit(
    "kurokawaren-utama",
    "kurokawaren",
    "Kartu utama",
  ),
  "kurokawaren-bajutradisional": ManhwaOutfit(
    "kurokawaren-bajutradisional",
    "kurokawaren",
    "Pakaian tradisional",
  ),
  "kurokawaren-jaketbomberhitam": ManhwaOutfit(
    "kurokawaren-jaketbomberhitam",
    "kurokawaren",
    "Jaket bomber hitam",
  ),
  "kurokawaren-seragamkampus": ManhwaOutfit(
    "kurokawaren-seragamkampus",
    "kurokawaren",
    "Seragam kampus",
  ),
  "kwontaehyuk-utama": ManhwaOutfit(
    "kwontaehyuk-utama",
    "kwontaehyuk",
    "Kartu utama",
  ),
  "kwontaehyuk-berkeringatmendengarkanmusik": ManhwaOutfit(
    "kwontaehyuk-berkeringatmendengarkanmusik",
    "kwontaehyuk",
    "Kaos · musik",
  ),
  "kwontaehyuk-gym": ManhwaOutfit(
    "kwontaehyuk-gym",
    "kwontaehyuk",
    "Pakaian gym",
  ),
  "kwontaehyuk-kasualtaskiri": ManhwaOutfit(
    "kwontaehyuk-kasualtaskiri",
    "kwontaehyuk",
    "Kaos kasual · tas",
  ),
  "kwontaehyuk-kaosputihbuku": ManhwaOutfit(
    "kwontaehyuk-kaosputihbuku",
    "kwontaehyuk",
    "Kaos putih · buku",
  ),
  "kwontaehyuk-renangkolam": ManhwaOutfit(
    "kwontaehyuk-renangkolam",
    "kwontaehyuk",
    "Pakaian renang · kolam",
  ),
  "leejunseo-utama": ManhwaOutfit(
    "leejunseo-utama",
    "leejunseo",
    "Kartu utama",
  ),
  "leejunseo-bacabukukaoskrem": ManhwaOutfit(
    "leejunseo-bacabukukaoskrem",
    "leejunseo",
    "Kaos krem · buku",
  ),
  "leejunseo-kamarkaosputih": ManhwaOutfit(
    "leejunseo-kamarkaosputih",
    "leejunseo",
    "Kaos putih · kamar",
  ),
  "leejunseo-kaosbirutokobuku": ManhwaOutfit(
    "leejunseo-kaosbirutokobuku",
    "leejunseo",
    "Kaos biru · toko buku",
  ),
  "leejunseo-sweetermerahbataperpustakaan": ManhwaOutfit(
    "leejunseo-sweetermerahbataperpustakaan",
    "leejunseo",
    "Sweter merah bata · perpustakaan",
  ),
  "linzixuan-utama": ManhwaOutfit(
    "linzixuan-utama",
    "linzixuan",
    "Kartu utama",
  ),
  "linzixuan-kasualtradisionalmodern": ManhwaOutfit(
    "linzixuan-kasualtradisionalmodern",
    "linzixuan",
    "Kasual tradisional modern",
  ),
  "linzixuan-lari": ManhwaOutfit("linzixuan-lari", "linzixuan", "Pakaian lari"),
  "namseojun-utama": ManhwaOutfit(
    "namseojun-utama",
    "namseojun",
    "Kartu utama",
  ),
  "namseojun-internetkafehoodiehitam": ManhwaOutfit(
    "namseojun-internetkafehoodiehitam",
    "namseojun",
    "Hoodie hitam · kafe",
  ),
  "namseojun-kaosberkeringatmengelap": ManhwaOutfit(
    "namseojun-kaosberkeringatmengelap",
    "namseojun",
    "Kaos · mengusap keringat",
  ),
  "namseojun-laptopatasanbirutua": ManhwaOutfit(
    "namseojun-laptopatasanbirutua",
    "namseojun",
    "Jaket biru tua · laptop",
  ),
  "suqinghuan-utama": ManhwaOutfit(
    "suqinghuan-utama",
    "suqinghuan",
    "Kartu utama",
  ),
  "suqinghuan-internetcafe": ManhwaOutfit(
    "suqinghuan-internetcafe",
    "suqinghuan",
    "Pakaian kafe",
  ),
  "suqinghuan-kaoskasual": ManhwaOutfit(
    "suqinghuan-kaoskasual",
    "suqinghuan",
    "Kaos kasual",
  ),
  "xuwenjing-utama": ManhwaOutfit(
    "xuwenjing-utama",
    "xuwenjing",
    "Kartu utama",
  ),
  "xuwenjing-hoodieputihbukulaptop": ManhwaOutfit(
    "xuwenjing-hoodieputihbukulaptop",
    "xuwenjing",
    "Hoodie putih · buku dan laptop",
  ),
  "zhangmingzhe-utama": ManhwaOutfit(
    "zhangmingzhe-utama",
    "zhangmingzhe",
    "Kartu utama",
  ),
  "zhangmingzhe-internetkafe": ManhwaOutfit(
    "zhangmingzhe-internetkafe",
    "zhangmingzhe",
    "Pakaian kafe",
  ),
  "zhangmingzhe-jakethitam": ManhwaOutfit(
    "zhangmingzhe-jakethitam",
    "zhangmingzhe",
    "Jaket hitam",
  ),
};

// ID lama tetap bisa ditampilkan tanpa masuk ke pilihan pakaian baru.
const manhwaLegacyAliases = <String, String>{
  "baekseoyeon-jaketabuabuelegan": "baekseoyeon-utama",
  "chahyunjae-kemejaabuabukampus": "chahyunjae-utama",
  "chaminhyuk-kasual": "chaminhyuk-utama",
  "choinari-hujanpayungbajupink": "choinari-utama",
  "hanseoah-kemejahitammapmap": "hanseoah-utama",
  "hanseoyul-kemejaputihkampus": "hanseoyul-utama",
  "kangjiwoo-kemejakampus": "kangjiwoo-utama",
  "kwontaehyuk-kemejamerah": "kwontaehyuk-utama",
  "leejunseo-kemejahitambus": "leejunseo-utama",
  "kimdasol-hoodiehijau": "kimdasol-utama",
  "namseojun-jaketdanhoodiehitam": "namseojun-utama",
};

String manhwaPrimaryCard(String characterId) => '$characterId-utama';
