import 'dart:async';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import '../../data/announcement_repository.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../table/player_status.dart';

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
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
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
              Text('Kabar desa dan log pembaruan',
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
            icon: const Icon(Icons.refresh_rounded),
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
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
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

    final meta = [
      isUpdate ? 'Pembaruan' : 'Pengumuman',
      if (version.isNotEmpty) 'v$version',
      _date(m['published_at'] as String?),
    ].where((e) => e.isNotEmpty).join('  ·  ');

    final card = Material(
      color: Colors.black.withValues(alpha: 0.36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unread
              ? accent.withValues(alpha: 0.85)
              : EmbunColors.goldDim.withValues(alpha: 0.5),
          width: unread ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasBody ? () => setState(() => _manual[id] = !open) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GameIcon(isUpdate ? 'logorhistory' : 'announcement',
                      size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${m['title']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                            color: EmbunColors.cream,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(meta,
                            style: TextStyle(
                                fontSize: 11.5,
                                letterSpacing: 0.3,
                                color: accent.withValues(alpha: 0.9))),
                      ],
                    ),
                  ),
                  if (hasBody)
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more_rounded,
                          color: Colors.white54),
                    ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: open
                    ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            accent.withValues(alpha: 0.6),
                            accent.withValues(alpha: 0),
                          ]),
                        ),
                      ),
                      _Body(text: body, accent: accent),
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          if (pinned || unread)
            Positioned(
              top: -8,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pinned)
                    const StatusTag(
                        text: 'Disematkan', color: EmbunColors.gold),
                  if (pinned && unread) const SizedBox(width: 6),
                  if (unread)
                    const StatusTag(text: 'Baru', color: EmbunColors.leaf),
                ],
              ),
            ),
        ],
      ),
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
      kind: EmbunButtonKind.secondary,
      height: 46,
      onPressed: _refreshing ? null : _load,
    ),
  );
}

/// Isi entri: baris berawalan "- " menjadi butir, baris kosong menjadi jarak,
/// sisanya paragraf biasa.
class _Body extends StatelessWidget {
  final String text;
  final Color accent;
  const _Body({required this.text, required this.accent});

  static const _style =
  TextStyle(fontSize: 13.5, height: 1.45, color: Colors.white70);

  @override
  Widget build(BuildContext context) {
    // Toleran: "\n" yang terketik literal (mis. dari Table Editor Supabase)
    // juga dianggap baris baru.
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final raw in lines)
          if (raw.trim().isEmpty)
            const SizedBox(height: 8)
          else if (raw.trimLeft().startsWith('- '))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(
                      child: Text(raw.trimLeft().substring(2), style: _style)),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(raw.trim(), style: _style),
            ),
      ],
    );
  }
}