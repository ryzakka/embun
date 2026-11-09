import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/art.dart';
import '../common/ornate.dart';

// =====================================================================
// Format isi pengumuman (kolom `body` di tabel `announcements`).
// Sengaja sederhana; satu baris = satu elemen:
//
//   # Judul bagian              judul kecil untuk mengelompokkan
//   - butir                     butir (awali 2 spasi = butir anak)
//   - [baru] butir              lencana pada butir: [baru] [ubah] [perbaikan]
//   [penting] teks              kotak sorot untuk satu hal yang wajib dibaca
//   **tebal**                   penekanan di dalam kalimat
//   [teks](https://...)         tautan di dalam kalimat (URL polos juga jadi tautan)
//   Unduh APK: https://...      baris tersendiri = kartu tautan
//   https://...                 baris tersendiri = kartu tautan
//
// Tautan .apk/.aab/.zip/.exe dst., rilis GitHub, Drive, dan sejenisnya tampil
// sebagai kartu UNDUH; Play Store / App Store sebagai kartu TOKO.
//
// Baris tanpa penanda tepat di bawah sebuah butir digabung ke butir itu, dan
// "\n" yang terketik literal di Table Editor Supabase dianggap baris baru.
// =====================================================================

enum LinkKind { download, store, web }

class LinkInfo {
  final LinkKind kind;
  final String badge; // mis. APK, ZIP; kosong untuk selain unduhan
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
      return LinkInfo(LinkKind.store, '', host);
    }
  }
  if (host.contains('github.com') && path.contains('/releases')) {
    return LinkInfo(LinkKind.download, '', host);
  }
  for (final d in _dlHosts) {
    if (host.contains(d)) return LinkInfo(LinkKind.download, '', host);
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

/// Tautan unduhan pertama di [body] (UNDUH lebih diutamakan daripada TOKO);
/// null bila tak ada.
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

enum _K { heading, bullet, callout, link, para, spacer }

class _Block {
  final _K k;
  String text;
  final String tag; // baru, ubah, perbaikan (kosong = tanpa)
  final int level; // 0 / 1 untuk butir
  final String url;
  _Block(this.k,
      {this.text = '', this.tag = '', this.level = 0, this.url = ''});
}

final _bulletTagRe =
RegExp(r'^\[(baru|ubah|perbaikan|fix)\]\s*', caseSensitive: false);
final _importantRe = RegExp(r'^\[penting\]\s*', caseSensitive: false);

List<_Block> _parse(String raw) {
  final lines = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(r'\n', '\n')
      .split('\n');
  final out = <_Block>[];

  final headRe = RegExp(r'^#{1,3}\s+(.+)$');
  final bulletRe = RegExp(r'^(\s*)([-*•])\s+(.+)$');
  final linkLabelRe = RegExp(r'^(?:([^:\n]{1,40}?)\s*:\s+)?(https?://\S+)$');
  final linkMdRe = RegExp(r'^\[([^\]]+)\]\((https?://[^\s)]+)\)$');

  for (final line in lines) {
    final t = line.trim();
    if (t.isEmpty) {
      if (out.isNotEmpty && out.last.k != _K.spacer) out.add(_Block(_K.spacer));
      continue;
    }
    var m = headRe.firstMatch(t);
    if (m != null) {
      out.add(_Block(_K.heading, text: m.group(1)!.trim()));
      continue;
    }
    m = bulletRe.firstMatch(line);
    if (m != null) {
      var content = m.group(3)!.trim();
      var tag = '';
      final tm = _bulletTagRe.firstMatch(content);
      if (tm != null) {
        tag = tm.group(1)!.toLowerCase();
        if (tag == 'fix') tag = 'perbaikan';
        content = content.substring(tm.end);
      }
      out.add(_Block(_K.bullet,
          text: content,
          tag: tag,
          level:
          (m.group(1)!.length >= 2 || m.group(1)!.contains('\t')) ? 1 : 0));
      continue;
    }
    m = linkMdRe.firstMatch(t);
    if (m != null) {
      out.add(_Block(_K.link,
          text: m.group(1)!.trim(), url: _stripTrailing(m.group(2)!)));
      continue;
    }
    m = linkLabelRe.firstMatch(t);
    if (m != null) {
      out.add(_Block(_K.link,
          text: (m.group(1) ?? '').trim(), url: _stripTrailing(m.group(2)!)));
      continue;
    }
    final im = _importantRe.firstMatch(t);
    if (im != null) {
      out.add(_Block(_K.callout, text: t.substring(im.end).trim()));
      continue;
    }
    // Baris lanjutan tepat di bawah butir: gabung ke butir itu.
    if (out.isNotEmpty && out.last.k == _K.bullet) {
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
      if (prev.k == _K.bullet && next.k == _K.bullet) continue;
    }
    tidy.add(b);
  }
  return tidy;
}

// ------------------------------ tampilan ------------------------------

final _inlineRe = RegExp(
  r'\*\*(.+?)\*\*' // 1 tebal
  r'|\[([^\]]+)\]\((https?://[^\s)]+)\)' // 2,3 tautan bertulisan
  r'|(https?://[^\s<>\]\)"]+)', // 4 tautan polos
);

const _linkColor = Color(0xFF8FD3FF);
const _blue = Color(0xFF6CB6FF);
const _body = TextStyle(fontSize: 14, height: 1.5, color: Color(0xDDFFFFFF));
const _bodySub = TextStyle(fontSize: 13, height: 1.45, color: Colors.white60);

(String, Color) _tagLook(String tag) => switch (tag) {
  'baru' => ('BARU', EmbunColors.leaf),
  'ubah' => ('UBAH', EmbunColors.gold),
  _ => ('PERBAIKAN', _blue),
};

/// Isi entri pengumuman (lihat penjelasan format di atas berkas).
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
      decorationColor: _linkColor.withValues(alpha: 0.5),
    ),
    recognizer: _tap(url),
  );

  List<InlineSpan> _spans(String s, TextStyle style) {
    final out = <InlineSpan>[];
    var pos = 0;
    for (final m in _inlineRe.allMatches(s)) {
      if (m.start > pos) out.add(TextSpan(text: s.substring(pos, m.start)));
      pos = m.end;
      if (m.group(1) != null) {
        out.add(TextSpan(
          text: m.group(1),
          style: style.copyWith(
              fontWeight: FontWeight.w800, color: EmbunColors.cream),
        ));
      } else if (m.group(2) != null) {
        out.add(_linkSpan(m.group(2)!, _stripTrailing(m.group(3)!), style));
      } else if (m.group(4) != null) {
        final raw = m.group(4)!;
        final url = _stripTrailing(raw);
        var shown = url.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
        if (shown.length > 44) shown = '${shown.substring(0, 43)}…';
        out.add(_linkSpan(shown, url, style));
        if (raw.length > url.length) {
          out.add(TextSpan(text: raw.substring(url.length)));
        }
      }
    }
    if (pos < s.length) out.add(TextSpan(text: s.substring(pos)));
    return out;
  }

  Widget _rich(String t, TextStyle s) =>
      Text.rich(TextSpan(style: s, children: _spans(t, s)));

  Widget _tagChip(String tag) {
    final (label, color) = _tagLook(tag);
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }

  Widget _block(_Block b, bool first) {
    final accent = widget.accent;
    switch (b.k) {
      case _K.spacer:
        return const SizedBox(height: 6);
      case _K.heading:
        return Padding(
          padding: EdgeInsets.only(top: first ? 0 : 12, bottom: 6),
          child: _rich(
            b.text,
            TextStyle(
              fontSize: 14.5,
              height: 1.3,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: accent,
            ),
          ),
        );
      case _K.bullet:
        final sub = b.level > 0;
        return Padding(
          padding: EdgeInsets.only(bottom: sub ? 4 : 6, left: sub ? 18.0 : 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: sub ? 4 : 5,
                height: sub ? 4 : 5,
                margin: EdgeInsets.only(top: sub ? 8.5 : 9, right: 10),
                decoration: BoxDecoration(
                  color: sub ? Colors.white38 : accent.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
              ),
              if (b.tag.isNotEmpty) _tagChip(b.tag),
              Expanded(child: _rich(b.text, sub ? _bodySub : _body)),
            ],
          ),
        );
      case _K.callout:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
            decoration: BoxDecoration(
              color: EmbunColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: EmbunColors.gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 8),
                  child: GameIcon('alert', size: 18),
                ),
                Expanded(
                  child: _rich(b.text, _body.copyWith(color: EmbunColors.cream)),
                ),
              ],
            ),
          ),
        );
      case _K.link:
        return _LinkCard(url: b.url, label: b.text.isEmpty ? null : b.text);
      case _K.para:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _rich(b.text, _body),
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
      children: [
        for (var i = 0; i < _blocks.length; i++) _block(_blocks[i], i == 0),
      ],
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
    final sub = [
      if (info.badge.isNotEmpty) info.badge,
      info.host,
    ].where((e) => e.isNotEmpty).join('  ·  ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: c.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openAnnouncementLink(context, url),
          onLongPress: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: url));
            messenger
                .showSnackBar(const SnackBar(content: Text('Tautan disalin.')));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(ic, color: c, size: 22),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: EmbunColors.cream,
                        ),
                      ),
                      if (sub.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, color: Colors.white54),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    cta,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B1A12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}