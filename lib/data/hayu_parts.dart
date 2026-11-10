enum HayuPart {
  akar('akar', 'Akar'),
  daun('leaves', 'Daun'),
  batang('batang', 'Batang'),
  tanah('tanah', 'Tanah');

  const HayuPart(this.effectKey, this.label);

  final String effectKey;
  final String label;
}

num? _effectAmount(Object? value) => switch (value) {
  num amount => amount,
  String amount => num.tryParse(amount),
  _ => null,
};

List<HayuPart> cardHayuParts(Map<String, dynamic>? def) {
  final effect = def?['effect'];
  if (effect is! Map) return const [];
  final trend = effect['trend'];
  final trendPart =
      trend is Map &&
          (_effectAmount(trend['per']) ?? 0) != 0 &&
          (_effectAmount(trend['nights']) ?? 0) > 0
      ? (trend['part'] as Object?)?.toString().toLowerCase()
      : null;
  // Ulat menggugurkan daun belakangan. Shear dapat mengubah perlindungan
  // yang tersisa menjadi kerusakan daun.
  final harmsLeaves =
      (_effectAmount(effect['worms']) ?? 0) > 0 ||
      (_effectAmount(effect['shear']) ?? 0) > 0;
  return [
    for (final part in HayuPart.values)
      if ((_effectAmount(effect[part.effectKey]) ?? 0) != 0 ||
          trendPart == part.name ||
          (part == HayuPart.daun && harmsLeaves))
        part,
  ];
}
