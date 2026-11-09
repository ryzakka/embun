import 'dart:async';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import '../../data/announcement_repository.dart';
import '../../data/app_info.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../table/player_status.dart';
import 'announcement_body.dart';

enum _Filter { all, pengumuman, pembaruan }

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Pengumuman dan log pembaruan, layar penuh. Membuka halaman ini menandai
/// semuanya sudah dibaca; entri yang baru ditandai "Baru" selama halaman
/// masih terbuka.
class AnnouncementsPage extends StatefulWidget {
  final AnnouncementRepository repo;
  const AnnouncementsPage({super.key, required this.repo});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  List<Map<String, dynamic>>? _items;
  Object? _error;
  bool _refreshing = false;
  bool _seenCaptured = false;
  int _seenAtOpen = 0;
  _Filter _filter = _Filter.all;

  /// Pilihan buka/tutup dari pemain; yang belum dipilih memakai bawaan.
  final Map<int, bool> _manual = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final items = await widget.repo.fetch();
      final maxId = items.isEmpty
          ? 0
          : items.map((m) => (m['id'] as num).toInt()).reduce(max);
      final seen = await widget.repo.lastSeen();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        if (!_seenCaptured) {
          _seenAtOpen = seen ?? maxId;
          _seenCaptured = true;
        }
      });
      if (maxId > 0) unawaited(widget.repo.markSeen(maxId));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  List<Map<String, dynamic>> _visible() {
    final all = _items ?? const <Map<String, dynamic>>[];
    return switch (_filter) {
      _Filter.all => all,
      _Filter.pengumuman => [
        for (final m in all)
          if (m['kind'] == 'pengumuman') m
      ],
      _Filter.pembaruan => [
        for (final m in all)
          if (m['kind'] == 'pembaruan') m
      ],
    };
  }

  /// Versi terbaru pada entri "pembaruan" yang lebih baru dari yang terpasang.
  String? _newerVersion(List<Map<String, dynamic>> items) {
    String? best;
    for (final m in items) {
      if (m['kind'] != 'pembaruan') continue;
      final v = ((m['version'] as String?) ?? '').trim();
      if (v.isEmpty || !AppInfo.isNewer(v)) continue;
      if (best == null || AppInfo.compare(v, best) > 0) best = v;
    }
    return best;
  }

  /// Banner versi baru. Bila entri pembaruannya memuat tautan unduhan, ada
  /// tombol "Unduh" langsung di sini.
  Widget _updateBanner(List<Map<String, dynamic>> items, String v) {
    DownloadLink? dl;
    for (final m in items) {
      if (m['kind'] != 'pembaruan') continue;
      if (((m['version'] as String?) ?? '').trim() != v) continue;
      dl = findDownloadLink((m['body'] as String?) ?? '');
      if (dl != null) break;
    }
    final link = dl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoticeStrip(
            icon: 'info',
            text: 'Versi V$v sudah tersedia (versimu ${AppInfo.tag}). '
                '${link != null ? 'Unduh pembaruannya di bawah ini.' : 'Muat ulang halaman atau perbarui aplikasimu.'}',
            accent: EmbunColors.gold,
          ),
          if (link != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: EmbunButton(
                label: 'Unduh V$v',
                kind: EmbunButtonKind.primary,
                expand: true,
                height: 46,
                onPressed: () => openAnnouncementLink(context, link.url),
              ),
            ),
        ],
      ),
    );
  }

  String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    return d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  // ============================ kerangka ============================

  @override
  Widget build(BuildContext context) {
    final bg = sceneryPath('balaidesa-dalamsiang') ??
        sceneryPath('rumahdesa-hijau');
    return Scaffold(
      backgroundColor: const Color(0xFF050A08),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(path: bg, dim: 0.66),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    _topBar(),
                    Expanded(child: _content()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
          color: EmbunColors.gold,
          icon: const GameIcon('back', size: 23),
        ),
        const GameIcon('logorhistory', size: 38),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pengumuman',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: EmbunColors.gold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              Text('Log pembaruan  ·  versimu ${AppInfo.tag}',
                  style: TextStyle(fontSize: 12, color: Colors.white60)),
            ],
          ),
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: _refreshing
              ? const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
              : IconButton(
            tooltip: 'Muat ulang',
            color: EmbunColors.gold,
            icon: const GameIcon('refresh', size: 25),
            onPressed: _load,
          ),
        ),
      ],
    ),
  );

  Widget _content() {
    final items = _items;
    if (items == null) {
      return _error == null ? _skeleton() : _failed();
    }
    final visible = _visible();
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: NoticeStrip(
                  icon: 'alert',
                  text: 'Gagal memuat ulang: ${errMsg(_error!)}',
                  accent: EmbunColors.blood,
                ),
              ),
            ),
          if (_newerVersion(items) case final v?)
            SliverToBoxAdapter(child: _updateBanner(items, v)),
          if (items.length >= 3)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _filters(),
              ),
            ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _message(
                icon: 'logorhistory',
                title: 'Belum ada pengumuman',
                body: 'Kabar dan catatan pembaruan akan muncul di sini.',
              ),
            )
          else if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _message(
                icon: 'logorhistory',
                title: 'Tidak ada entri',
                body: 'Belum ada entri untuk pilihan ini.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: _card(visible[i], i),
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Text(
                'Tarik ke bawah untuk memuat ulang.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    ChoiceChip chip(String label, _Filter f) => ChoiceChip(
      label: Text(label),
      selected: _filter == f,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _filter = f),
    );
    return Wrap(
      spacing: 8,
      children: [
        chip('Semua', _Filter.all),
        chip('Pengumuman', _Filter.pengumuman),
        chip('Pembaruan', _Filter.pembaruan),
      ],
    );
  }

  // ============================ kartu entri ============================

  Widget _card(Map<String, dynamic> m, int index) {
    final id = (m['id'] as num).toInt();
    final isUpdate = m['kind'] == 'pembaruan';
    final accent = isUpdate ? EmbunColors.leaf : EmbunColors.gold;
    final unread = id > _seenAtOpen;
    final pinned = m['pinned'] == true;
    final body = ((m['body'] as String?) ?? '').trim();
    final version = ((m['version'] as String?) ?? '').trim();
    final hasBody = body.isNotEmpty;
    final open = hasBody && (_manual[id] ?? (unread || pinned || index == 0));
    final dl = isUpdate ? findDownloadLink(body) : null;
    final newer = isUpdate && version.isNotEmpty && AppInfo.isNewer(version);

    // Baris kecil di bawah judul: versi (bila ada) dan tanggal.
    final meta = [
      if (version.isNotEmpty)
        AppInfo.isCurrent(version) ? 'v$version (terpasang)' : 'v$version',
      _date(m['published_at'] as String?),
    ].where((e) => e.isNotEmpty).join('  ·  ');

    final card = Material(
      color: Colors.black.withValues(alpha: 0.38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unread
              ? accent.withValues(alpha: 0.8)
              : EmbunColors.goldDim.withValues(alpha: 0.45),
          width: unread ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasBody ? () => setState(() => _manual[id] = !open) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GameIcon(isUpdate ? 'logorhistory' : 'announcement', size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tingkat 1: jenis + penanda status (kecil, tenang).
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              isUpdate ? 'PEMBARUAN' : 'PENGUMUMAN',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: accent.withValues(alpha: 0.95),
                              ),
                            ),
                            if (pinned)
                              const StatusTag(
                                  text: 'Disematkan', color: EmbunColors.gold),
                            if (unread)
                              const StatusTag(
                                  text: 'Baru', color: EmbunColors.leaf),
                            if (newer)
                              const StatusTag(
                                  text: 'Versi baru', color: EmbunColors.gold),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Tingkat 2: judul, paling menonjol.
                        Text(
                          '${m['title']}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: EmbunColors.cream,
                          ),
                        ),
                        // Tingkat 3: versi dan tanggal.
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(meta,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white54)),
                        ],
                      ],
                    ),
                  ),
                  if (hasBody)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more_rounded,
                            color: Colors.white54),
                      ),
                    ),
                ],
              ),
              // Versi baru dengan tautan unduhan: tombol terlihat walau tertutup.
              if (newer && dl != null && !open)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: EmbunButton(
                    label: 'Unduh V$version',
                    kind: EmbunButtonKind.primary,
                    expand: true,
                    height: 44,
                    onPressed: () => openAnnouncementLink(context, dl.url),
                  ),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: open
                    ? Padding(
                  padding: const EdgeInsets.only(top: 12, right: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white12,
                      ),
                      AnnouncementBody(text: body, accent: accent),
                    ],
                  ),
                )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: '${isUpdate ? 'Pembaruan' : 'Pengumuman'}: ${m['title']}',
      child: card,
    );
  }

  // ============================ keadaan lain ============================

  Widget _skeleton() => ListView.separated(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    itemCount: 4,
    separatorBuilder: (_, _) => const SizedBox(height: 16),
    itemBuilder: (_, _) => Container(
      height: 84,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.3)),
      ),
    ),
  );

  Widget _message({
    required String icon,
    required String title,
    required String body,
    Widget? action,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(opacity: 0.55, child: GameIcon(icon, size: 72)),
                const SizedBox(height: 14),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: EmbunColors.gold)),
                const SizedBox(height: 6),
                Text(body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.4, color: Colors.white60)),
                if (action != null) ...[
                  const SizedBox(height: 18),
                  action,
                ],
              ],
            ),
          ),
        ),
      );

  Widget _failed() => _message(
    icon: 'alert',
    title: 'Tidak bisa dimuat',
    body: errMsg(_error!),
    action: EmbunButton(
      label: 'Coba lagi',
      icon: 'refresh',
      kind: EmbunButtonKind.secondary,
      height: 46,
      onPressed: _refreshing ? null : _load,
    ),
  );
}