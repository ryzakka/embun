import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/ornate.dart';

// =====================================================================
// Format isi pengumuman (kolom `body` di tabel `announcements`).
//
// Satu baris = satu elemen. Yang dikenali:
//
//   # Judul bagian              judul besar (## dan ### = anak judul)
//   - butir   * butir   • butir butir biasa (awali 2 spasi = butir anak)
//   + teks                      butir berlencana BARU
//   ~ teks                      butir berlencana UBAH
//   ! teks                      butir berlencana PENTING
//   - [perbaikan] teks          lencana: [baru] [ubah] [perbaikan] [penting]
//                               [hapus] pada butir mana pun
//   1. langkah                  daftar bernomor
//   > kutipan                   kutipan
//   [info] teks                 kotak sorot: [info] [tips] [awas] [penting] [baru]
//   ---                         garis pemisah
//   Unduh APK: https://...      kartu tautan (label: tautan)
//   https://...                 kartu tautan (tautan saja, satu baris)
//   [Label](https://...)        kartu tautan (satu baris)
//
// Di dalam kalimat: **tebal**  *miring*  `kode`  ==sorot==
//                   [teks](https://...)  dan tautan polos https://...
//
// Tautan berakhiran .apk/.aab/.zip/.exe dst., rilis GitHub, Drive, MediaFire,
// dan sejenisnya tampil sebagai kartu UNDUH; Play Store / App Store sebagai
// kartu TOKO; lainnya kartu TAUTAN biasa.
//
// Baris lanjutan (tanpa penanda) tepat di bawah sebuah butir digabung ke butir
// itu, dan "\n" yang terketik literal di Table Editor Supabase dianggap baris
// baru, sehingga isi lama tetap rapi.
// =====================================================================

enum LinkKind { download, store, web }

class LinkInfo {
  final LinkKind kind;
  final String badge; // mis. APK, ZIP, TOKO; kosong untuk tautan biasa
  final String host;
  const LinkInfo(this.kind, this.badge, this.host);
}

const _dlExt = {
  'apk', 'aab', 'xapk', 'apks', 'exe', 'msi', 'dmg', 'pkg', 'ipa', //
  'zip', 'rar', '7z',
};
const _dlHosts = [
  'drive.google.com', 'mediafire.com', 'mega.nz', 'mega.io', 'dropbox.com',
  'sourceforge.net', 'itch.io', 'dl.',
];
const _storeHosts = [
  'play.google.com', 'apps.apple.com', 'testflight.apple.com',
  'appgallery.huawei.com', 'apps.microsoft.com',
];

LinkInfo classifyLink(String url) {
  final u = Uri.tryParse(url);
  final host =
  (u?.host ?? '').toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final path = (u?.path ?? '').toLowerCase();
  final dot = path.lastIndexOf('.');
  final ext = dot >= 0 ? path.substring(dot + 1) : '';
  if (_dlExt.contains(ext)) {
    return LinkInfo(LinkKind.download, ext.toUpperCase(), host);
  }
  for (final s in _storeHosts) {
    if (host == s || host.endsWith('.$s')) {
      return LinkInfo(LinkKind.store, 'TOKO', host);
    }
  }
  if (host.contains('github.com') && path.contains('/releases')) {
    return LinkInfo(LinkKind.download, 'RILIS', host);
  }
  for (final d in _dlHosts) {
    if (host.contains(d)) return LinkInfo(LinkKind.download, 'BERKAS', host);
  }
  return LinkInfo(LinkKind.web, '', host);
}

class DownloadLink {
  final String url;
  final LinkInfo info;
  const DownloadLink(this.url, this.info);
}

final _urlRe = RegExp(r'https?://[^\s<>\]\)"]+');

String _stripTrailing(String u) => u.replaceFirst(RegExp(r'[.,;:!?]+$'), '');

/// Tautan unduhan pertama di [body] (kartu UNDUH lebih diutamakan daripada
/// TOKO); null bila tak ada.
DownloadLink? findDownloadLink(String body) {
  final text = body.replaceAll(r'\n', '\n');
  DownloadLink? store;
  for (final m in _urlRe.allMatches(text)) {
    final url = _stripTrailing(m.group(0)!);
    final info = classifyLink(url);
    if (info.kind == LinkKind.download) return DownloadLink(url, info);
    if (info.kind == LinkKind.store) store ??= DownloadLink(url, info);
  }
  return store;
}

/// Membuka tautan di peramban / aplikasi luar. Hanya http(s); bila gagal,
/// tautannya disalin ke papan klip.
Future<void> openAnnouncementLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    final uri = Uri.parse(url);
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
  if (!ok) {
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(const SnackBar(
        content: Text('Tidak bisa membuka tautan. Tautan disalin.')));
  }
}

// ------------------------------ parser ------------------------------

enum _K { heading, sub, bullet, numbered, quote, callout, divider, para, link, spacer }

class _Block {
  final _K k;
  String text;
  final String tag; // baru, ubah, ... (kosong = tanpa)
  final int level; // 0 / 1 untuk butir
  final int n; // nomor untuk daftar bernomor
  final String url;
  _Block(this.k,
      {this.text = '', this.tag = '', this.level = 0, this.n = 0, this.url = ''});
}

final _tagRe = RegExp(
    r'^\[(baru|ubah|perbaikan|fix|penting|hapus|info|tips|awas|peringatan)\]\s*',
    caseSensitive: false);

String _normTag(String t) {
  final s = t.toLowerCase();
  if (s == 'fix') return 'perbaikan';
  if (s == 'peringatan') return 'awas';
  return s;
}

bool _isList(_Block? b) => b != null && (b.k == _K.bullet || b.k == _K.numbered);

List<_Block> _parse(String raw) {
  final lines = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(r'\n', '\n')
      .split('\n');
  final out = <_Block>[];

  final dividerRe = RegExp(r'^([-*_])\1{2,}$');
  final headRe = RegExp(r'^(#{1,3})\s+(.+)$');
  final quoteRe = RegExp(r'^>\s?(.*)$');
  final numRe = RegExp(r'^(\s*)(\d{1,2})[.)]\s+(.+)$');
  final bulletRe = RegExp(r'^(\s*)([-*•+~!])\s+(.+)$');
  final linkLabelRe = RegExp(r'^(?:([^:\n]{1,40}?)\s*:\s+)?(https?://\S+)$');
  final linkMdRe = RegExp(r'^\[([^\]]+)\]\((https?://[^\s)]+)\)$');

  for (final line in lines) {
    final t = line.trim();
    if (t.isEmpty) {
      if (out.isNotEmpty && out.last.k != _K.spacer) out.add(_Block(_K.spacer));
      continue;
    }
    if (dividerRe.hasMatch(t)) {
      out.add(_Block(_K.divider));
      continue;
    }
    var m = headRe.firstMatch(t);
    if (m != null) {
      out.add(_Block(m.group(1)!.length == 1 ? _K.heading : _K.sub,
          text: m.group(2)!.trim()));
      continue;
    }
    m = quoteRe.firstMatch(t);
    if (m != null) {
      out.add(_Block(_K.quote, text: m.group(1)!.trim()));
      continue;
    }
    m = numRe.firstMatch(line);
    if (m != null) {
      out.add(_Block(_K.numbered,
          text: m.group(3)!.trim(),
          n: int.tryParse(m.group(2)!) ?? 1,
          level: m.group(1)!.length >= 2 ? 1 : 0));
      continue;
    }
    m = bulletRe.firstMatch(line);
    if (m != null) {
      var content = m.group(3)!.trim();
      var tag = switch (m.group(2)) {
        '+' => 'baru',
        '~' => 'ubah',
        '!' => 'penting',
        _ => '',
      };
      final tm = _tagRe.firstMatch(content);
      if (tm != null) {
        tag = _normTag(tm.group(1)!);
        content = content.substring(tm.end);
      }
      out.add(_Block(_K.bullet,
          text: content,
          tag: tag,
          level: (m.group(1)!.length >= 2 || m.group(1)!.contains('\t')) ? 1 : 0));
      continue;
    }
    m = linkMdRe.firstMatch(t);
    if (m != null) {
      out.add(_Block(_K.link, text: m.group(1)!.trim(), url: _stripTrailing(m.group(2)!)));
      continue;
    }
    m = linkLabelRe.firstMatch(t);
    if (m != null) {
      out.add(_Block(_K.link,
          text: (m.group(1) ?? '').trim(), url: _stripTrailing(m.group(2)!)));
      continue;
    }
    final tm = _tagRe.firstMatch(t);
    if (tm != null) {
      out.add(_Block(_K.callout,
          text: t.substring(tm.end).trim(), tag: _normTag(tm.group(1)!)));
      continue;
    }
    // Baris lanjutan tepat di bawah butir: gabung ke butir itu.
    if (out.isNotEmpty && _isList(out.last)) {
      out.last.text = '${out.last.text} $t';
      continue;
    }
    out.add(_Block(_K.para, text: t));
  }

  // Rapikan jarak: tanpa jarak di antara butir, tanpa jarak di awal / akhir.
  final tidy = <_Block>[];
  for (var i = 0; i < out.length; i++) {
    final b = out[i];
    if (b.k == _K.spacer) {
      final prev = tidy.isEmpty ? null : tidy.last;
      final next = i + 1 < out.length ? out[i + 1] : null;
      if (prev == null || next == null) continue;
      if (_isList(prev) && _isList(next)) continue;
    }
    tidy.add(b);
  }
  return tidy;
}

// ------------------------------ inline ------------------------------

final _inlineRe = RegExp(
  r'\*\*(.+?)\*\*' // 1 tebal
  r'|`([^`]+)`' // 2 kode
  r'|==(.+?)==' // 3 sorot
  r'|\[([^\]]+)\]\((https?://[^\s)]+)\)' // 4,5 tautan bertulisan
  r'|(https?://[^\s<>\]\)"]+)' // 6 tautan polos
  r'|(?<![\w*])\*(?!\s)([^*]+?)(?<!\s)\*(?![\w*])', // 7 miring
);

const _linkColor = Color(0xFF8FD3FF);
const _blue = Color(0xFF6CB6FF);
const _base = TextStyle(fontSize: 13.5, height: 1.45, color: Colors.white70);

class _TagStyle {
  final String label;
  final Color color;
  final IconData icon;
  const _TagStyle(this.label, this.color, this.icon);
}

_TagStyle _tagStyle(String tag) => switch (tag) {
  'baru' => const _TagStyle('BARU', EmbunColors.leaf, Icons.auto_awesome_rounded),
  'ubah' => const _TagStyle('UBAH', EmbunColors.gold, Icons.tune_rounded),
  'perbaikan' => const _TagStyle('PERBAIKAN', _blue, Icons.build_rounded),
  'penting' =>
  const _TagStyle('PENTING', EmbunColors.blood, Icons.priority_high_rounded),
  'hapus' => const _TagStyle('DIHAPUS', EmbunColors.mist, Icons.delete_outline_rounded),
  'info' => const _TagStyle('INFO', _blue, Icons.info_outline_rounded),
  'tips' => const _TagStyle('TIPS', EmbunColors.leaf, Icons.lightbulb_outline_rounded),
  'awas' => const _TagStyle('AWAS', EmbunColors.blood, Icons.warning_amber_rounded),
  _ => const _TagStyle('', EmbunColors.gold, Icons.circle),
};

/// Isi entri pengumuman dengan format kaya (lihat penjelasan di atas berkas).
class AnnouncementBody extends StatefulWidget {
  final String text;
  final Color accent;
  const AnnouncementBody({super.key, required this.text, required this.accent});

  @override
  State<AnnouncementBody> createState() => _AnnouncementBodyState();
}

class _AnnouncementBodyState extends State<AnnouncementBody> {
  late List<_Block> _blocks = _parse(widget.text);
  final List<TapGestureRecognizer> _recs = [];

  @override
  void didUpdateWidget(covariant AnnouncementBody old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _blocks = _parse(widget.text);
  }

  @override
  void dispose() {
    for (final r in _recs) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tap(String url) {
    final r = TapGestureRecognizer()
      ..onTap = () => openAnnouncementLink(context, url);
    _recs.add(r);
    return r;
  }

  TextSpan _linkSpan(String label, String url, TextStyle style) => TextSpan(
    text: label,
    style: style.copyWith(
      color: _linkColor,
      decoration: TextDecoration.underline,
      decorationColor: _linkColor.withValues(alpha: 0.55),
    ),
    recognizer: _tap(url),
  );

  List<InlineSpan> _spans(String s, TextStyle style, int depth) {
    final out = <InlineSpan>[];
    var pos = 0;
    for (final m in _inlineRe.allMatches(s)) {
      if (m.start > pos) out.add(TextSpan(text: s.substring(pos, m.start)));
      pos = m.end;
      if (m.group(1) != null) {
        final bold = style.copyWith(
            fontWeight: FontWeight.w800, color: EmbunColors.cream);
        out.add(TextSpan(
          style: bold,
          children:
          depth < 2 ? _spans(m.group(1)!, bold, depth + 1) : [TextSpan(text: m.group(1))],
        ));
      } else if (m.group(2) != null) {
        out.add(TextSpan(
          text: ' ${m.group(2)} ',
          style: style.copyWith(
            fontFamily: 'monospace',
            fontSize: (style.fontSize ?? 13.5) - 0.5,
            color: EmbunColors.gold,
            backgroundColor: Colors.black.withValues(alpha: 0.35),
          ),
        ));
      } else if (m.group(3) != null) {
        out.add(TextSpan(
          text: m.group(3),
          style: style.copyWith(
            color: EmbunColors.cream,
            backgroundColor: widget.accent.withValues(alpha: 0.28),
          ),
        ));
      } else if (m.group(4) != null) {
        out.add(_linkSpan(m.group(4)!, _stripTrailing(m.group(5)!), style));
      } else if (m.group(6) != null) {
        final raw = m.group(6)!;
        final url = _stripTrailing(raw);
        final trail = raw.substring(url.length);
        var shown = url.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
        if (shown.length > 46) shown = '${shown.substring(0, 45)}…';
        out.add(_linkSpan(shown, url, style));
        if (trail.isNotEmpty) out.add(TextSpan(text: trail));
      } else if (m.group(7) != null) {
        out.add(TextSpan(
          text: m.group(7),
          style: style.copyWith(fontStyle: FontStyle.italic),
        ));
      }
    }
    if (pos < s.length) out.add(TextSpan(text: s.substring(pos)));
    return out;
  }

  Widget _rich(String t, TextStyle s) =>
      Text.rich(TextSpan(style: s, children: _spans(t, s, 0)));

  Widget _chip(_TagStyle ts) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: ts.color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: ts.color.withValues(alpha: 0.7)),
    ),
    child: Text(
      ts.label,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: ts.color,
      ),
    ),
  );

  /// Kotak dengan garis tebal di kiri (kutipan dan kotak sorot).
  Widget _barBox({required Color color, required Widget child, double fill = 0.12}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: color.withValues(alpha: fill),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _block(_Block b) {
    final accent = widget.accent;
    switch (b.k) {
      case _K.spacer:
        return const SizedBox(height: 8);
      case _K.divider:
        return Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              accent.withValues(alpha: 0),
              accent.withValues(alpha: 0.65),
              accent.withValues(alpha: 0),
            ]),
          ),
        );
      case _K.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 17,
                decoration: BoxDecoration(
                    color: accent, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _rich(
                  b.text,
                  const TextStyle(
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: EmbunColors.gold,
                  ),
                ),
              ),
            ],
          ),
        );
      case _K.sub:
        return Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 3),
          child: _rich(
            b.text,
            const TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w800,
              color: EmbunColors.cream,
            ),
          ),
        );
      case _K.bullet:
        final ts = b.tag.isEmpty ? null : _tagStyle(b.tag);
        return Padding(
          padding: EdgeInsets.only(bottom: 5, left: b.level * 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ts != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: _chip(ts),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 10),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: b.level == 0 ? accent : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 1),
                    ),
                  ),
                ),
              Expanded(child: _rich(b.text, _base)),
            ],
          ),
        );
      case _K.numbered:
        return Padding(
          padding: EdgeInsets.only(bottom: 6, left: b.level * 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 10, top: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.18),
                  border: Border.all(color: accent.withValues(alpha: 0.8)),
                ),
                child: Text('${b.n}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accent)),
              ),
              Expanded(child: _rich(b.text, _base)),
            ],
          ),
        );
      case _K.quote:
        return _barBox(
          color: Colors.white54,
          fill: 0.07,
          child: _rich(
            b.text,
            _base.copyWith(fontStyle: FontStyle.italic, color: Colors.white60),
          ),
        );
      case _K.callout:
        final ts = _tagStyle(b.tag);
        return _barBox(
          color: ts.color,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 9),
                child: Icon(ts.icon, size: 18, color: ts.color),
              ),
              Expanded(
                child: b.text.isEmpty
                    ? Text(ts.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ts.color))
                    : _rich(b.text, _base.copyWith(color: Colors.white)),
              ),
            ],
          ),
        );
      case _K.link:
        return _LinkCard(
            url: b.url, label: b.text.isEmpty ? null : b.text);
      case _K.para:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _rich(b.text, _base),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pengenal ketuk dibuat ulang tiap build; yang lama dibuang.
    for (final r in _recs) {
      r.dispose();
    }
    _recs.clear();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final b in _blocks) _block(b)],
    );
  }
}

/// Kartu tautan: UNDUH (hijau), TOKO (ungu), atau TAUTAN biasa (emas).
/// Ketuk untuk membuka; tekan lama untuk menyalin tautan.
class _LinkCard extends StatelessWidget {
  final String url;
  final String? label;
  const _LinkCard({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    final info = classifyLink(url);
    final (Color c, IconData ic, String def, String cta) = switch (info.kind) {
      LinkKind.download =>
      (EmbunColors.leaf, Icons.download_rounded, 'Unduh pembaruan', 'Unduh'),
      LinkKind.store => (
      EmbunColors.mist,
      Icons.storefront_rounded,
      'Buka di toko aplikasi',
      'Buka'
      ),
      LinkKind.web =>
      (EmbunColors.gold, Icons.open_in_new_rounded, 'Buka tautan', 'Buka'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.withValues(alpha: 0.24), c.withValues(alpha: 0.06)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.75)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => openAnnouncementLink(context, url),
            onLongPress: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: url));
              messenger.showSnackBar(
                  const SnackBar(content: Text('Tautan disalin.')));
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(ic, color: c, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label ?? def,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: EmbunColors.cream,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (info.badge.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(info.badge,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: c)),
                              ),
                              const SizedBox(width: 7),
                            ],
                            Flexible(
                              child: Text(
                                info.host,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11.5, color: Colors.white54),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ic, size: 17, color: const Color(0xFF0B1A12)),
                        const SizedBox(width: 4),
                        Text(cta,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0B1A12))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}