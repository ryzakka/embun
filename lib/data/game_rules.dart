/// Angka aturan yang ditampilkan di tutorial dan panduan.
/// Bila aturan di server berubah, cukup ubah di sini.
const int kLeavesMax = 30; // daun untuk kemenangan warga
const int kCycleDays = 3; // satu siklus: 2 hari biasa + malam persembahan
const int kStrikesMax = 2; // nyawa tiap pemain (tuduhan 1 = kurungan, 2 = keluar)
const int kVoteSeconds = 45; // lama voting
const int kOfferingMax = 2; // kartu maksimum per persembahan
const int kMinPlayers = 3;
const int kMinDuaTerbisikPlayers = 5;
const int kMaxPlayers = 8;

int minPlayersFor(int antagonistCount) =>
    antagonistCount == 2 ? kMinDuaTerbisikPlayers : kMinPlayers;

String antagonistModeLabel(int antagonistCount) =>
    antagonistCount == 2 ? 'Dua Terbisik' : 'Satu Terbisik';
