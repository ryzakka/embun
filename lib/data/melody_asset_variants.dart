/// Preserve the directory and basename, preferring WebP over PNG. A manifest
/// avoids probing missing URLs; null means the manifest was unavailable.
List<String> melodyAssetCandidates(String path, {Set<String>? available}) {
  final stem = path.replaceFirst(
    RegExp(r'\.(png|webp)$', caseSensitive: false),
    '',
  );
  return [
    for (final extension in const ['webp', 'png'])
      if (available == null || available.contains('$stem.$extension'))
        '$stem.$extension',
  ];
}

/// A file that exists but fails to load/decode must not hide the other format.
/// Returning null retains the art view's existing text/shape fallback.
Future<T?> loadMelodyAssetVariant<T>(
  String path,
  Future<T> Function(String candidate) load, {
  Set<String>? available,
}) async {
  for (final candidate in melodyAssetCandidates(path, available: available)) {
    try {
      return await load(candidate);
    } catch (_) {
      // Try the next available format, including when the first is corrupt.
    }
  }
  return null;
}
