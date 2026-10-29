import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';

/// Adegan pembukaan suara setelah voting selesai: kartu-kartu yang memilih
/// muncul satu per satu ("Nelayan memilih Warga Desa"), hitungan di papan
/// bawah naik, ada jeda "MAYORITAS" saat suara penentu masuk, lalu yang tidak
/// memilih, lalu hasil. Berjalan SEBELUM adegan kurungan / fajar / akhir.
///
/// [rows] berasal dari tabel `vote_reveal` (urutan server, sama untuk semua
/// perangkat; yang tidak memilih di akhir).
class VoteRevealScene extends StatefulWidget {
  final int day;
  final List<Map<String, dynamic>> rows;
  final String myId;
  final VoidCallback onDone;

  const VoteRevealScene({
    super.key,
    required this.day,
    required this.rows,
    required this.myId,
    required this.onDone,
  });

  @override
  State<VoteRevealScene> createState() => _VoteRevealSceneState();
}

class _Person {
  final String id;
  final String name;
  final String? card;
  const _Person(this.id, this.name, this.card);
}

class _VoteRevealSceneState extends State<VoteRevealScene> {
  static const _bg = Color(0xFF05080F);

  late final List<Map<String, dynamic>> _votes;
  late final List<Map<String, dynamic>> _abstain;
  late final List<_Person> _people;
  late final int _total;
  String? _myTarget;

  final Map<String, int> _counts = {};
  int _phase = 0; // 0 judul, 1 pemilihan, 2 tidak memilih, 3 hasil
  int _i = 0; // suara yang sedang tampil
  int _stage = 0; // 0 kosong, 1 pemilih muncul, 2 + sasaran, 3 terhitung
  String? _majorityId;
  bool _banner = false;
  bool _stopped = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final rows = widget.rows;
    _votes = [for (final r in rows) if (r['target_id'] != null) r];
    _abstain = [for (final r in rows) if (r['target_id'] == null) r];
    _total = rows.length;

    final seen = <String>{};
    final people = <_Person>[];
    for (final r in rows) {
      final id = r['voter_id'] as String;
      if (seen.add(id)) {
        people.add(_Person(id, '${r['voter_name']}', r['voter_card'] as String?));
      }
    }
    // Susunan papan stabil (urut nama), bukan urutan pemilihan.
    people.sort((a, b) => a.name.compareTo(b.name));
    _people = people;

    for (final r in rows) {
      if (r['voter_id'] == widget.myId) _myTarget = r['target_id'] as String?;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _stopped = true;
    super.dispose();
  }

  // ------------------------- alur waktu -------------------------

  Future<bool> _w(int ms) async {
    await Future.delayed(Duration(milliseconds: ms));
    return mounted && !_stopped;
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _stopped = true;
    widget.onDone();
  }

  Future<void> _play() async {
    if (!await _w(800)) return;
    setState(() => _phase = 1);

    final n = _votes.length;
    for (var i = 0; i < n; i++) {
      final v = _votes[i];
      final tid = v['target_id'] as String;

      // Irama: normal di awal, melambat di sepertiga akhir selama belum ada
      // mayoritas (menahan napas), dan mengebut setelah mayoritas jatuh.
      final tense = _majorityId == null && i >= (n * 2 / 3).floor();
      final m = _majorityId != null ? 0.62 : (tense ? 1.3 : 1.0);

      setState(() {
        _i = i;
        _stage = 1; // pemilih muncul
      });
      if (!await _w((470 * m).round())) return;

      setState(() => _stage = 2); // panah + sasaran
      if (!await _w((430 * m).round())) return;

      setState(() {
        _stage = 3; // terhitung
        _counts[tid] = (_counts[tid] ?? 0) + 1;
      });
      HapticFeedback.selectionClick();

      if (_majorityId == null && (_counts[tid]! * 2 > _total)) {
        _majorityId = tid;
        setState(() => _banner = true);
        HapticFeedback.heavyImpact();
        if (!await _w(1250)) return;
        setState(() => _banner = false);
      }
      if (!await _w((560 * m).round())) return;
    }

    setState(() => _stage = 0);

    if (_abstain.isNotEmpty) {
      setState(() => _phase = 2);
      if (!await _w(1700)) return;
    }

    setState(() => _phase = 3);
    HapticFeedback.mediumImpact();
    if (!await _w(2300)) return;
    _finish();
  }

  // ------------------------- data bantu -------------------------

  _Person? _person(String? id) {
    for (final p in _people) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Pemenang akhir: satu-satunya yang melewati separuh suara.
  String? get _winnerId {
    for (final e in _counts.entries) {
      if (e.value * 2 > _total) return e.key;
    }
    return null;
  }

  String _targetName(Map<String, dynamic> v) => '${v['target_name']}';
  String _voterName(Map<String, dynamic> v) => '${v['voter_name']}';

  // ------------------------- tampilan -------------------------

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.35),
                radius: 1.15,
                colors: [Color(0xFF1B1233), _bg],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _top(),
                Expanded(child: _stageArea()),
                _board(),
                const SizedBox(height: 10),
              ],
            ),
          ),
          if (_banner) _majorityBanner(),
        ],
      ),
    );
  }

  Widget _top() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 8, 0),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suara Terbuka',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: EmbunColors.gold,
                ),
              ),
              Text(
                'Hari ${widget.day} · siapa memilih siapa',
                style: const TextStyle(fontSize: 12.5, color: Colors.white54),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _finish,
          icon: const Icon(Icons.fast_forward_rounded, size: 20),
          label: const Text('Lewati'),
          style: TextButton.styleFrom(foregroundColor: Colors.white60),
        ),
      ],
    ),
  );

  Widget _stageArea() => LayoutBuilder(builder: (context, c) {
    final cardW = math
        .min(math.min(c.maxWidth * 0.28, (c.maxHeight - 90) * 3 / 4), 128.0)
        .clamp(52.0, 128.0)
        .toDouble();
    final Widget body = switch (_phase) {
      0 => const Text(
        'Semua suara dibuka...',
        style: TextStyle(fontSize: 16, color: Colors.white60),
      ),
      1 => _voteStage(cardW),
      2 => _abstainStage(),
      _ => _resultStage(cardW),
    };
    // Diskalakan turun bila layar pendek (ponsel miring) agar tak meluap.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth * 0.9),
          child: Center(child: body),
        ),
      ),
    );
  });

  // ---------- satu suara ----------

  Widget _voteStage(double cardW) {
    if (_stage == 0 || _i >= _votes.length) return const SizedBox.shrink();
    final v = _votes[_i];
    final voterMine = v['voter_id'] == widget.myId;
    final targetMine = v['target_id'] == widget.myId;
    final showTarget = _stage >= 2;

    return Column(
      key: ValueKey('vote$_i'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                    offset: Offset(-48 * (1 - t), 0), child: child),
              ),
              child: _VoteCard(
                name: _voterName(v),
                card: v['voter_card'] as String?,
                width: cardW,
                tag: voterMine ? 'Suaramu' : null,
                glow: voterMine ? EmbunColors.gold : EmbunColors.leaf,
                ring: voterMine,
              ),
            ),
            SizedBox(
              width: cardW * 0.62,
              height: cardW * 4 / 3 + 22,
              child: showTarget
                  ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 300),
                builder: (_, t, child) => Opacity(
                    opacity: t,
                    child: Transform.scale(scale: 0.6 + 0.4 * t, child: child)),
                child: Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Center(
                    child: Icon(Icons.arrow_forward_rounded,
                        size: cardW * 0.4, color: EmbunColors.blood),
                  ),
                ),
              )
                  : null,
            ),
            SizedBox(
              width: cardW + 24,
              child: showTarget
                  ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (_, t, child) => Opacity(
                    opacity: t.clamp(0.0, 1.0).toDouble(),
                    child: Transform.scale(scale: 0.55 + 0.45 * t, child: child)),
                child: _VoteCard(
                  name: _targetName(v),
                  card: v['target_card'] as String?,
                  width: cardW,
                  tag: targetMine ? 'Kamu' : null,
                  glow: EmbunColors.blood,
                  ring: targetMine,
                ),
              )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        AnimatedOpacity(
          opacity: showTarget ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              children: [
                TextSpan(
                  text: voterMine ? 'Kamu' : _voterName(v),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: voterMine ? EmbunColors.gold : Colors.white,
                  ),
                ),
                const TextSpan(text: '  memilih  '),
                TextSpan(
                  text: targetMine ? 'kamu' : _targetName(v),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: EmbunColors.blood,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ---------- tidak memilih ----------

  Widget _abstainStage() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (_, t, child) => Opacity(opacity: t, child: child),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.do_not_disturb_on_outlined,
                  size: 34, color: Colors.white54),
              const SizedBox(height: 6),
              const Text('Tidak memilih',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70)),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final r in _abstain)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlayerAvatar(
                          path: protagonistPath(
                              (r['voter_card'] as String?) ?? 'default'),
                          size: 44,
                          ring: r['voter_id'] == widget.myId
                              ? EmbunColors.gold
                              : Colors.white30,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r['voter_id'] == widget.myId
                              ? '${r['voter_name']} (kamu)'
                              : '${r['voter_name']}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: r['voter_id'] == widget.myId
                                ? EmbunColors.gold
                                : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- hasil ----------

  Widget _resultStage(double cardW) {
    final wid = _winnerId;
    final w = _person(wid);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: 0.8 + 0.2 * t, child: child)),
      child: w == null
          ? Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.balance_rounded, size: 56, color: Colors.white54),
          SizedBox(height: 10),
          Text('Tidak ada yang mencapai mayoritas',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70)),
          SizedBox(height: 4),
          Text('Butuh lebih dari separuh suara.',
              style: TextStyle(fontSize: 12.5, color: Colors.white54)),
        ],
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('DITUDUH MAYORITAS',
              style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w800,
                  color: EmbunColors.blood)),
          const SizedBox(height: 8),
          _VoteCard(
            name: w.name,
            card: w.card,
            width: cardW * 1.1,
            tag: w.id == widget.myId ? 'Kamu' : null,
            glow: EmbunColors.blood,
            ring: w.id == widget.myId,
          ),
          const SizedBox(height: 2),
          Text('${_counts[wid] ?? 0} dari $_total suara',
              style: const TextStyle(fontSize: 13, color: Colors.white60)),
        ],
      ),
    );
  }

  // ---------- papan hitungan ----------

  Widget _board() {
    final wid = _phase == 3 ? _winnerId : null;
    final focus = (_phase == 1 && _stage >= 2 && _i < _votes.length)
        ? _votes[_i]['target_id'] as String?
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in _people)
            AnimatedOpacity(
              opacity: (_phase == 3 && wid != null && p.id != wid) ? 0.32 : 1,
              duration: const Duration(milliseconds: 400),
              child: _Tile(
                person: p,
                count: _counts[p.id] ?? 0,
                focused: focus == p.id,
                winner: wid == p.id,
                me: p.id == widget.myId,
                votedByMe: _myTarget == p.id && _phase >= 1 && _myVoteShown(p.id),
              ),
            ),
        ],
      ),
    );
  }

  /// Tanda "suaramu" di papan baru muncul setelah suaraku sendiri dibuka.
  bool _myVoteShown(String targetId) {
    if (_phase >= 2) return true;
    for (var k = 0; k <= _i && k < _votes.length; k++) {
      final v = _votes[k];
      if (v['voter_id'] == widget.myId && v['target_id'] == targetId) {
        return k < _i || _stage >= 3;
      }
    }
    return false;
  }

  Widget _majorityBanner() {
    final p = _person(_majorityId);
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -0.5),
          child: TweenAnimationBuilder<double>(
            key: const ValueKey('banner'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (_, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0).toDouble(),
              child: Transform.scale(scale: 0.5 + 0.5 * t, child: child),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              decoration: BoxDecoration(
                color: EmbunColors.blood.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: EmbunColors.blood.withValues(alpha: 0.6),
                      blurRadius: 36),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('MAYORITAS',
                      style: TextStyle(
                          fontSize: 28,
                          letterSpacing: 5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  if (p != null)
                    Text(p.id == widget.myId ? 'Kamu' : p.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu karakter dengan nama. Slot atas (22 px) selalu ada supaya kartu
/// pemilih dan sasaran sejajar, dengan atau tanpa tanda ("Suaramu", "Kamu").
class _VoteCard extends StatelessWidget {
  final String name;
  final String? card;
  final double width;
  final String? tag;
  final Color glow;
  final bool ring;

  const _VoteCard({
    required this.name,
    required this.card,
    required this.width,
    required this.glow,
    this.tag,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width + 24,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 22,
          child: tag == null
              ? null
              : Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
            decoration: BoxDecoration(
              color: EmbunColors.gold,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(tag!,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF07130F))),
          ),
        ),
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: ring
                ? Border.all(color: EmbunColors.gold, width: 3)
                : null,
          ),
          child: CardArt(
            path: protagonistPath(card ?? 'default'),
            width: width,
            glow: glow,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 13.5, height: 1.2, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

/// Satu pemain di papan hitungan: avatar, nama, dan jumlah suara.
class _Tile extends StatelessWidget {
  final _Person person;
  final int count;
  final bool focused;
  final bool winner;
  final bool me;
  final bool votedByMe;

  const _Tile({
    required this.person,
    required this.count,
    required this.focused,
    required this.winner,
    required this.me,
    required this.votedByMe,
  });

  @override
  Widget build(BuildContext context) {
    final border = winner
        ? EmbunColors.blood
        : focused
        ? EmbunColors.gold
        : me
        ? EmbunColors.gold.withValues(alpha: 0.55)
        : Colors.white24;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 68,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      transform: Matrix4.diagonal3Values(
          winner ? 1.08 : (focused ? 1.05 : 1.0),
          winner ? 1.08 : (focused ? 1.05 : 1.0),
          1),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: winner
            ? EmbunColors.blood.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: focused ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: border, width: (winner || focused) ? 2 : 1.2),
        boxShadow: (winner || focused)
            ? [
          BoxShadow(
              color: (winner ? EmbunColors.blood : EmbunColors.gold)
                  .withValues(alpha: 0.4),
              blurRadius: 14),
        ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              PlayerAvatar(
                path: protagonistPath(person.card ?? 'default'),
                size: 36,
                ring: me ? EmbunColors.gold : Colors.white38,
              ),
              if (votedByMe)
                Positioned(
                  left: -4,
                  top: -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: EmbunColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF05080F), width: 1.5),
                    ),
                    child: const Icon(Icons.how_to_vote_rounded,
                        size: 8, color: Color(0xFF05080F)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: me ? EmbunColors.gold : Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                child: child),
            child: Text(
              count == 0 ? '·' : '$count',
              key: ValueKey(count),
              style: TextStyle(
                fontSize: count == 0 ? 14 : 19,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: count == 0
                    ? Colors.white30
                    : (winner ? EmbunColors.blood : EmbunColors.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}