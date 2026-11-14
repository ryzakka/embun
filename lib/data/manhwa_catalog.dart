const manhwaDir = 'assets/kartu/CharProManhwaEdition';
const manhwaTheme = 'manhwa';
const defaultTheme = 'default';

class ManhwaOutfit {
  const ManhwaOutfit(this.id, this.characterId, this.label);
  final String id, characterId, label;
}

const manhwaNames = <String, String>{
  "baekseoyeon": "Baek Seo-yeon",
  "chahyunjae": "Cha Hyun-jae",
  "chaminhyuk": "Cha Min-hyuk",
  "choinari": "Choi Na-ri",
  "hanseoah": "Han Seo-ah",
  "hanseoyul": "Han Seo-yul",
  "kangjiwoo": "Kang Ji-woo",
  "kwontaehyuk": "Kwon Tae-hyuk",
  "leejunseo": "Lee Jun-seo",
  "kimdasol": "Kim Da-sol",
  "namseojun": "Nam Seo-jun",
};
const manhwaOutfits = <String, ManhwaOutfit>{
  "baekseoyeon-jaketabuabuelegan": ManhwaOutfit(
    "baekseoyeon-jaketabuabuelegan",
    "baekseoyeon",
    "Jaket abu-abu",
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
  "chahyunjae-jaketbasket": ManhwaOutfit(
    "chahyunjae-jaketbasket",
    "chahyunjae",
    "Jaket basket",
  ),
  "chahyunjae-kemejaabuabukampus": ManhwaOutfit(
    "chahyunjae-kemejaabuabukampus",
    "chahyunjae",
    "Kemeja abu-abu · kampus",
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
  "chaminhyuk-kasual": ManhwaOutfit(
    "chaminhyuk-kasual",
    "chaminhyuk",
    "Pakaian kasual",
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
  "choinari-belanjagenit": ManhwaOutfit(
    "choinari-belanjagenit",
    "choinari",
    "Pakaian belanja",
  ),
  "choinari-hujanpayungbajupink": ManhwaOutfit(
    "choinari-hujanpayungbajupink",
    "choinari",
    "Pink · payung",
  ),
  "choinari-kelasseragam": ManhwaOutfit(
    "choinari-kelasseragam",
    "choinari",
    "Seragam kelas",
  ),
  "choinari-pinktaskecil": ManhwaOutfit(
    "choinari-pinktaskecil",
    "choinari",
    "Pink · tas kecil",
  ),
  "choinari-putihpita": ManhwaOutfit(
    "choinari-putihpita",
    "choinari",
    "Blus berpita",
  ),
  "choinari-ungu": ManhwaOutfit("choinari-ungu", "choinari", "Sweter ungu"),
  "hanseoah-bubblebajupink": ManhwaOutfit(
    "hanseoah-bubblebajupink",
    "hanseoah",
    "Pink · minuman",
  ),
  "hanseoah-eleganputih": ManhwaOutfit(
    "hanseoah-eleganputih",
    "hanseoah",
    "Pakaian putih",
  ),
  "hanseoah-kaosputihponsel": ManhwaOutfit(
    "hanseoah-kaosputihponsel",
    "hanseoah",
    "Kaos putih · ponsel",
  ),
  "hanseoah-kemejahitammapmap": ManhwaOutfit(
    "hanseoah-kemejahitammapmap",
    "hanseoah",
    "Kemeja hitam · map",
  ),
  "hanseoah-lari": ManhwaOutfit("hanseoah-lari", "hanseoah", "Pakaian lari"),
  "hanseoah-laritrek": ManhwaOutfit(
    "hanseoah-laritrek",
    "hanseoah",
    "Pakaian trek lari",
  ),
  "hanseoah-pinkminum": ManhwaOutfit(
    "hanseoah-pinkminum",
    "hanseoah",
    "Pink · tumbler",
  ),
  "hanseoyul-minimarketsweeterhitam": ManhwaOutfit(
    "hanseoyul-minimarketsweeterhitam",
    "hanseoyul",
    "Sweter hitam · minimarket",
  ),
  "hanseoyul-kasualkaoskrem": ManhwaOutfit(
    "hanseoyul-kasualkaoskrem",
    "hanseoyul",
    "Kaos krem",
  ),
  "hanseoyul-kemejaputihkampus": ManhwaOutfit(
    "hanseoyul-kemejaputihkampus",
    "hanseoyul",
    "Kemeja putih · kampus",
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
  "kangjiwoo-gamerkaosputih": ManhwaOutfit(
    "kangjiwoo-gamerkaosputih",
    "kangjiwoo",
    "Kaos putih · gaming",
  ),
  "kangjiwoo-kemejakampus": ManhwaOutfit(
    "kangjiwoo-kemejakampus",
    "kangjiwoo",
    "Kemeja kampus",
  ),
  "kangjiwoo-lari": ManhwaOutfit("kangjiwoo-lari", "kangjiwoo", "Pakaian lari"),
  "kangjiwoo-sweeterhitamkafe": ManhwaOutfit(
    "kangjiwoo-sweeterhitamkafe",
    "kangjiwoo",
    "Sweter hitam · kafe",
  ),
  "kwontaehyuk-berkeringatmendengarkanmusik": ManhwaOutfit(
    "kwontaehyuk-berkeringatmendengarkanmusik",
    "kwontaehyuk",
    "Kaos · musik",
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
  "kwontaehyuk-kemejamerah": ManhwaOutfit(
    "kwontaehyuk-kemejamerah",
    "kwontaehyuk",
    "Kemeja merah",
  ),
  "kwontaehyuk-renangkolam": ManhwaOutfit(
    "kwontaehyuk-renangkolam",
    "kwontaehyuk",
    "Pakaian renang · kolam",
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
  "leejunseo-kemejahitambus": ManhwaOutfit(
    "leejunseo-kemejahitambus",
    "leejunseo",
    "Kemeja hitam · halte",
  ),
  "leejunseo-sweetermerahbataperpustakaan": ManhwaOutfit(
    "leejunseo-sweetermerahbataperpustakaan",
    "leejunseo",
    "Sweter merah bata · perpustakaan",
  ),
  "kimdasol-hoodiehijau": ManhwaOutfit(
    "kimdasol-hoodiehijau",
    "kimdasol",
    "Hoodie hijau",
  ),
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
  "namseojun-laptopatasanbirutua": ManhwaOutfit(
    "namseojun-laptopatasanbirutua",
    "namseojun",
    "Jaket biru tua · laptop",
  ),
  "namseojun-jaketdanhoodiehitam": ManhwaOutfit(
    "namseojun-jaketdanhoodiehitam",
    "namseojun",
    "Jaket dan hoodie hitam",
  ),
  "namseojun-internetkafehoodiehitam": ManhwaOutfit(
    "namseojun-internetkafehoodiehitam",
    "namseojun",
    "Hoodie hitam · kafe",
  ),
};
