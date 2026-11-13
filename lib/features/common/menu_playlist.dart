/// Urutan musik menu. Nama aset sebenarnya dipertahankan untuk hosting
/// yang membedakan huruf besar/kecil.
class MenuPlaylist {
  static const files = [
    'musiklatar-1.mp3',
    'musiklatar-2.mp3',
    'musiklatar-3.mp3',
    'musiklatar-4.mp3',
  ];

  MenuPlaylist([Iterable<String> tracks = files]) : _tracks = List.of(tracks);
  List<String> _tracks;
  int _index = 0;
  String? get current => _tracks.isEmpty ? null : _tracks[_index];

  String? advance() {
    if (_tracks.isNotEmpty) _index = (_index + 1) % _tracks.length;
    return current;
  }

  void replace(Iterable<String> tracks) {
    final previous = current;
    _tracks = List.of(tracks);
    final found = previous == null ? -1 : _tracks.indexOf(previous);
    _index = found < 0 ? 0 : found;
  }

  static String _key(String file) =>
      file.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static List<String> fromAssets(Iterable<String> assets) {
    final byName = <String, String>{};
    final sorted = assets.where((p) => p.startsWith('assets/sound/')).toList()
      ..sort();
    for (final path in sorted) {
      final file = path.substring('assets/sound/'.length);
      if (!file.contains('/')) byName.putIfAbsent(_key(file), () => file);
    }
    return [
      for (final name in files)
        if (byName[_key(name)] != null) byName[_key(name)]!,
    ];
  }
}
