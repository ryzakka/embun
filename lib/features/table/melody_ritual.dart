import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/melody_rules.dart';
import '../../data/melody_music.dart';
import '../../data/melody_audio.dart';
import '../common/art.dart';
import '../common/embun_icon.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import 'melody_fx.dart';

typedef MelodyRow = Map<String, dynamic>;

/// Persistent on the game table, so invitations reach players in any place.
/// Only its owner's result is returned by the server; no role/other score feed.
class MelodyRitualLayer extends StatefulWidget {
  const MelodyRitualLayer({
    super.key,
    required this.repo,
    required this.gameId,
    required this.enabled,
    required this.hand,
    required this.defs,
    required this.balance,
    required this.antagonist,
    this.onChanged,
  });
  final GameRepository repo;
  final String gameId;
  final bool enabled, antagonist;
  final List<MelodyRow> hand;
  final Map<String, MelodyRow> defs;
  final double balance;
  final VoidCallback? onChanged;
  @override
  State<MelodyRitualLayer> createState() => _MelodyRitualLayerState();
}

class _MelodyRitualLayerState extends State<MelodyRitualLayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  MelodyRow? _state;
  OverlayEntry? _overlay;
  String? _error, _handId;
  String _payment = 'embun';
  bool _loading = false, _sending = false, _busy = false;
  Timer? _poll, _flush;
  late final AnimationController _frames = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );
  final _focus = FocusNode(debugLabel: 'Pelataran Melodi');
  final Set<int> _pressed = {};
  MelodyJudge _judge = MelodyJudge();
  Duration _offset = Duration.zero;
  DateTime? _lastPoll, _lastServerStamp;
  final _legacyAudio = _LegacyRitualAudio();
  bool _musicFailed = false, _background = false;
  late final _music = MelodyMusicController(
    _RitualAudioPort(),
    onError: (failed) {
      if (mounted && failed != _musicFailed) {
        _rebuild(() => _musicFailed = failed);
      }
    },
  );
  final _fx = MelodyFxController(laneColors: _colors);
  String? _audioSession;
  final Set<String> _refreshed = {};
  static const _keys = [
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyF,
    LogicalKeyboardKey.keyJ,
    LogicalKeyboardKey.keyK,
  ];
  static const _icons = [
    'pohonindikator-tanah',
    'pohonindikator-akar',
    'pohonindikator-batang',
    'pohonindikator-daun',
  ];
  static const _names = ['Tanah', 'Akar', 'Batang', 'Daun'];
  static const _colors = [
    Color(0xFFC9A875),
    Color(0xFF70C4D5),
    Color(0xFFDFB75D),
    Color(0xFF8AD17D),
  ];
  void _rebuild(VoidCallback change) {
    if (!mounted) {
      return;
    }
    setState(change);
    _overlay?.markNeedsBuild();
  }

  void _syncOverlay() {
    if (!mounted) {
      return;
    }
    if (!widget.enabled || _status == 'idle') {
      _closeOverlay();
      return;
    }
    if (_overlay == null) {
      _overlay = OverlayEntry(
        builder: (_) => Positioned.fill(child: _surface()),
      );
      Overlay.of(context, rootOverlay: true).insert(_overlay!);
    } else {
      _overlay!.markNeedsBuild();
    }
  }

  void _closeOverlay() {
    final entry = _overlay;
    _overlay = null;
    if (entry != null) {
      entry.remove();
      entry.dispose();
    }
  }

  int get _duration => melodySessionDuration(_state);
  String get _status => '${_state?['status'] ?? 'idle'}';
  MelodyRow get _own => Map<String, dynamic>.from(_state?['own'] as Map? ?? {});
  DateTime get _now => DateTime.now().add(_offset);
  int get _elapsed {
    final start = DateTime.tryParse('${_state?['starts_at'] ?? ''}');
    return start == null ? -9999 : _now.difference(start).inMilliseconds;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _frames.addListener(_frame);
    _poll = Timer.periodic(const Duration(milliseconds: 700), (_) => _load());
    _flush = Timer.periodic(const Duration(milliseconds: 100), (_) => _send());
    Sfx.I.muted.addListener(_muteChanged);
    MelodyFxLevel.load();
    MelodyFxLevel.level.addListener(_fxLevelChanged);
    if (widget.enabled) {
      _load();
    }
  }

  void _fxLevelChanged() => _rebuild(() {});

  @override
  void didUpdateWidget(covariant MelodyRitualLayer old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !old.enabled) {
      _load();
    }
    if (!widget.enabled) {
      _frames.stop();
      Sfx.I.setDuck(this, false);
      _release();
      _legacyAudio.stop();
      _music.stop();
      _closeOverlay();
    }
  }

  @override
  void dispose() {
    _closeOverlay();
    WidgetsBinding.instance.removeObserver(this);
    Sfx.I.muted.removeListener(_muteChanged);
    MelodyFxLevel.level.removeListener(_fxLevelChanged);
    Sfx.I.setDuck(this, false);
    _poll?.cancel();
    _flush?.cancel();
    _frames.dispose();
    _focus.dispose();
    _legacyAudio.dispose();
    unawaited(_music.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    if (_background) {
      _release();
      _send();
    }
    _frame();
  }

  void _prepareAudio() {
    if (_state != null && melodyTrackFromState(_state) != null) {
      final f = melodyMusicFrame(
        _state!,
        _elapsed,
        muted: Sfx.I.muted.value || _background,
      );
      if (f != null) _music.sync(f);
    } else if (!Sfx.I.muted.value) {
      _legacyAudio.prepare();
    }
  }

  void _muteChanged() {
    _prepareAudio();
    if (!Sfx.I.muted.value) _music.retry();
    _legacyAudio.mute(Sfx.I.muted.value);
  }

  void _frame() {
    if (!mounted || _status != 'running') {
      return;
    }
    final t = _elapsed;
    _judge.tick(t);
    _fx.held = _judge.pressed;
    _fx.setCombo(_judge.combo);
    if (t >= _duration && _pressed.isNotEmpty) {
      _release();
    }
    if (melodyTrackFromState(_state) != null) {
      _prepareAudio();
      if (t >= _duration + melodyFadeMs) Sfx.I.setDuck(this, false);
    } else if (t >= 0 && t < _duration) {
      final wave = (t ~/ 6000).clamp(0, 4).toInt();
      final rows = (_state?['waves'] as List? ?? []).cast<Map>();
      final pressure =
          (rows.where((r) => r['wave'] == wave).firstOrNull?['pressure']
                  as num?)
              ?.toInt() ??
          0;
      _legacyAudio.sync(
        wave,
        widget.antagonist ? 0 : pressure,
        t - wave * 6000,
        Sfx.I.muted.value || _background,
      );
    } else if (t >= _duration) {
      _legacyAudio.stop();
    }
  }

  Future<void> _load({bool force = false}) async {
    if (!widget.enabled || _loading || _sending) {
      return;
    }
    if (_status == 'idle' &&
        !force &&
        _lastPoll != null &&
        DateTime.now().difference(_lastPoll!).inMilliseconds < 1800) {
      return;
    }
    _loading = true;
    _lastPoll = DateTime.now();
    final sent = DateTime.now();
    try {
      final s = await widget.repo.melodyStatus(widget.gameId);
      _receive(s, sent);
    } catch (e) {
      if (mounted && _status != 'idle') {
        _rebuild(
          () => _error =
              'Koneksi melambat. Ketukan tetap berjalan; menyambungkan kembali…',
        );
      }
    } finally {
      _loading = false;
    }
  }

  void _receive(MelodyRow state, DateTime sent) {
    if (!mounted || !widget.enabled) {
      return;
    }
    final end = DateTime.now();
    final server = DateTime.tryParse('${state['server_now'] ?? ''}');
    if (server != null &&
        _lastServerStamp != null &&
        server.isBefore(_lastServerStamp!)) {
      return;
    }
    if (server != null) {
      _lastServerStamp = server;
    }
    if (server != null) {
      final estimate = server.difference(
        sent.add(
          Duration(microseconds: end.difference(sent).inMicroseconds ~/ 2),
        ),
      );
      _offset = _state?['id'] != state['id']
          ? estimate
          : Duration(
              microseconds:
                  _offset.inMicroseconds +
                  (estimate - _offset).inMicroseconds
                      .clamp(-15000, 15000)
                      .toInt(),
            );
    }
    if (state['id'] != _state?['id']) {
      _judge = MelodyJudge(durationMs: melodySessionDuration(state));
      _legacyAudio.stop();
      _music.stop();
      _musicFailed = false;
      _fx.reset();
      _pressed.clear();
      _payment = 'embun';
      _handId = null;
    }
    if (state['notes'] is List) {
      _judge.addNotes(
        (state['notes'] as List).cast<Map>().map(MelodyNote.fromJson),
      );
    }
    _rebuild(() {
      _state = state;
      _error = null;
    });
    _syncOverlay();
    final status = '${state['status']}';
    if (status == 'running' || status == 'inviting' || status == 'settled') {
      if (!_frames.isAnimating) {
        _frames.repeat();
      }
    } else {
      _frames.stop();
    }
    Sfx.I.setDuck(this, status == 'running');
    if (status == 'inviting') _prepareAudio();
    if (status == 'running') {
      if (_audioSession != state['id']) {
        _audioSession = '${state['id']}';
        _prepareAudio();
        _focus.requestFocus();
      }
      if (_refreshed.add('paid-${state['id']}')) {
        widget.onChanged?.call();
      }
    } else {
      _legacyAudio.stop();
      if (status != 'inviting') _music.stop();
    }
    if (status == 'settled' && _refreshed.add('reward-${state['id']}')) {
      widget.onChanged?.call();
    }
  }

  Future<void> _respond(bool accept) async {
    if (_busy || _state?['id'] == null) {
      return;
    }
    _rebuild(() => _busy = true);
    final sent = DateTime.now();
    try {
      _prepareAudio();
      _receive(
        await widget.repo.respondMelody(
          widget.gameId,
          '${_state!['id']}',
          accept: accept,
          payment: accept ? _payment : null,
          handId: accept ? _handId : null,
        ),
        sent,
      );
    } catch (e) {
      if (mounted) {
        _rebuild(() => _error = errMsg(e));
      }
    } finally {
      if (mounted) {
        _rebuild(() => _busy = false);
      }
    }
  }

  Future<void> _dismiss() async {
    if (_busy || _state?['id'] == null) {
      return;
    }
    _rebuild(() => _busy = true);
    try {
      await widget.repo.dismissMelody(widget.gameId, '${_state!['id']}');
      if (mounted) {
        _lastServerStamp = _now;
        _rebuild(() => _state = null);
        _syncOverlay();
      }
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        _rebuild(() => _error = errMsg(e));
      }
    } finally {
      if (mounted) {
        _rebuild(() => _busy = false);
      }
    }
  }

  void _down(int lane) {
    if (_status != 'running' ||
        _elapsed < 0 ||
        _elapsed >= _duration ||
        !_pressed.add(lane)) {
      return;
    }
    final note = _judge.down(lane, _elapsed);
    _fx.press(lane, true);
    if (note == null) {
      _fx.hit(lane, MelodyHitKind.stray);
    } else {
      _fx.hit(
        lane,
        _judge.feedback == 'Tepat!'
            ? MelodyHitKind.perfect
            : MelodyHitKind.good,
        hold: note.hold > 0,
      );
    }
    HapticFeedback.selectionClick();
  }

  void _up(int lane) {
    _pressed.remove(lane);
    _fx.press(lane, false);
    _judge.up(lane, _elapsed);
  }

  void _release() {
    for (final lane in _pressed.toList()) {
      _up(lane);
    }
  }

  Future<void> _send() async {
    if (_sending || _status != 'running' || !widget.enabled) {
      return;
    }
    final inputs = _judge.takeInputs();
    if (inputs.isEmpty) {
      return;
    }
    _sending = true;
    final sent = DateTime.now();
    final sid = '${_state!['id']}';
    try {
      final s = await widget.repo.playMelody(
        widget.gameId,
        sid,
        inputs.take(32).toList(),
      );
      if (inputs.length > 32) {
        _judge.returnInputs(inputs.skip(32).toList());
      }
      if (_state?['id'] == sid) {
        _receive(s, sent);
      }
    } catch (e) {
      // Retry only packets still inside the server's latency allowance.
      if (_state?['id'] == sid && _status == 'running') {
        _judge.returnInputs(
          inputs.where((e) => _elapsed - (e['at'] as int) < 1100).toList(),
        );
      }
      if (mounted) {
        _rebuild(() => _error = 'Koneksi melambat; mengirim ulang ketukan…');
      }
    } finally {
      _sending = false;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
  Widget _surface() {
    final settled = _status == 'settled';
    final tier = melodyTier((_own['final_score'] as num? ?? 0).toInt());
    final ambientTint = widget.antagonist
        ? EmbunColors.mist
        : settled
        ? melodyTierColor(tier)
        : EmbunColors.gold;
    return PopScope(
      canPop: false,
      child: Material(
        color: const Color(0xFF07110F),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (firstScenery([
                  'tempat-pelataranmelodi',
                  'alunalun-tiangberpita',
                  'pohon-keranjangbuah',
                ])
                case final path?)
              Opacity(
                opacity: .23,
                child: GameImage(path: path, fit: BoxFit.cover),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    EmbunColors.gold.withValues(alpha: .10),
                    const Color(0xED06100D),
                  ],
                ),
              ),
            ),
            if (_status != 'running')
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: MelodyAmbientPainter(
                      tint: ambientTint,
                      intensity: settled ? .4 + tier * .1 : .35,
                      frames: _frames,
                      level: MelodyFxLevel.level.value,
                      reduced: MediaQuery.disableAnimationsOf(context),
                    ),
                  ),
                ),
              ),
            SafeArea(child: _status == 'running' ? _play() : _panel()),
          ],
        ),
      ),
    );
  }

  Widget _panel() {
    final players = (_state?['players'] as List? ?? []).cast<Map>();
    final inviter = players
        .where((p) => p['user_id'] == _state?['inviter_id'])
        .firstOrNull;
    final accepted = _own['accepted'] == true;
    final cards = widget.hand.where((h) {
      final d = widget.defs[h['card_id']];
      return d != null &&
          (d['cost'] as num? ?? 0) >= 10 &&
          d['purchasable'] == true &&
          !['embun_biasa', 'embun_samaran'].contains(h['card_id']);
    }).toList();
    final valid = _payment == 'embun'
        ? widget.balance >= 8
        : cards.any((c) => c['id'] == _handId);
    final seconds =
        (DateTime.tryParse(
                  '${_state?['expires_at']}',
                )?.difference(_now).inSeconds ??
                0)
            .clamp(0, 25);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MelodyTitle(
                text: 'PELATARAN MELODI',
                color: widget.antagonist ? EmbunColors.mist : EmbunColors.gold,
                reduced: MediaQuery.disableAnimationsOf(context),
              ),
              const SizedBox(height: 14),
              if (_status == 'inviting') ...[
                Text(
                  '${inviter?['name'] ?? 'Seorang pemain'} mengundang seluruh pemain untuk hadir.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: EmbunColors.cream,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Musik ${(melodyTrackFromState(_state)?.id ?? 'klasik').replaceAll('instrument', '')} · ${_duration ~/ 1000} detik',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: EmbunColors.gold),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _frames,
                  builder: (_, _) => Text(
                    'Menunggu persetujuan • ${(DateTime.tryParse('${_state?['expires_at']}')?.difference(_now).inSeconds ?? seconds).clamp(0, 25)} detik',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    for (final p in players)
                      Chip(
                        avatar: EmbunIcon(
                          p['accepted'] == true
                              ? Icons.check_circle
                              : Icons.hourglass_empty,
                          size: 20,
                        ),
                        label: Text('${p['name']}'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pilih 8 embun atau bakar satu kartu item dengan harga dasar minimal 10. Semua biaya baru dipotong setelah seluruh pemain bersedia.',
                  style: TextStyle(color: EmbunColors.cream, height: 1.5),
                ),
                const SizedBox(height: 10),
                if (!accepted) ...[
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'embun', label: Text('8 embun')),
                      ButtonSegment(
                        value: 'card',
                        label: Text('Bakar kartu ≥10'),
                      ),
                    ],
                    selected: {_payment},
                    onSelectionChanged: _busy
                        ? null
                        : (s) => _rebuild(() => _payment = s.first),
                  ),
                  const SizedBox(height: 10),
                  if (_payment == 'embun')
                    Text(
                      'Saldo: ${widget.balance.toStringAsFixed(1)}',
                      style: const TextStyle(color: EmbunColors.gold),
                    ),
                  if (_payment == 'card')
                    DropdownButtonFormField<String>(
                      initialValue: cards.any((c) => c['id'] == _handId)
                          ? _handId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kartu yang dikorbankan',
                      ),
                      items: [
                        for (final c in cards)
                          DropdownMenuItem(
                            value: '${c['id']}',
                            child: Text(
                              '${widget.defs[c['card_id']]?['name']} • ${widget.defs[c['card_id']]?['cost']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => _rebuild(() => _handId = v),
                    ),
                  if (_payment == 'card' && cards.isEmpty)
                    const Text(
                      'Belum ada kartu yang memenuhi harga dasar minimal 10.',
                      style: TextStyle(color: Colors.amber),
                    ),
                  const SizedBox(height: 12),
                  EmbunButton(
                    label: _busy ? 'Menunggu…' : 'Bersedia dan pilih biaya',
                    onPressed: _busy || !valid ? null : () => _respond(true),
                  ),
                ] else
                  const Text(
                    'Kamu sudah bersedia. Menunggu semua pemain…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: EmbunColors.leaf),
                  ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy ? null : () => _respond(false),
                  child: const Text('Batalkan undangan • biaya tidak dipotong'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'D F J K atau empat tombol sentuh • tekan bersamaan untuk kombinasi • tahan saat ada jejak panjang. Nilai memakai 70% ketepatan dan 30% kombo terpanjang.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                TextButton(
                  onPressed: () => showMelodyRewardPool(context),
                  child: const Text('Lihat peluang hadiah'),
                ),
              ] else if (_status == 'settled') ...[
                MelodyScoreReveal(
                  key: ValueKey('score-${_state?['id']}'),
                  score: (_own['final_score'] as num? ?? 0).toInt(),
                  tier: melodyTier((_own['final_score'] as num? ?? 0).toInt()),
                  label:
                      'Nilai hadiah • kelompok ${melodyBands[melodyTier((_own['final_score'] as num? ?? 0).toInt())]}',
                  reduced: MediaQuery.disableAnimationsOf(context),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nilai pribadi ${_own['personal_score']} • ketepatan ${(_own['accuracy'] as num? ?? 0).toStringAsFixed(1)}% • kombo ${_own['max_combo']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: EmbunColors.cream),
                ),
                const SizedBox(height: 18),
                MelodyReveal(
                  key: ValueKey('reward-${_state?['id']}'),
                  delay: .6,
                  reduced: MediaQuery.disableAnimationsOf(context),
                  child: _reward(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Hadiah sudah masuk ke saldo atau tanganmu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                EmbunButton(
                  label: 'Kembali menjelajah',
                  onPressed: _busy ? null : _dismiss,
                ),
              ] else ...[
                Text(
                  '${_state?['reason'] ?? 'Undangan selesai.'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: EmbunColors.cream,
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                EmbunButton(
                  label: 'Kembali',
                  onPressed: _busy ? null : _dismiss,
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.amber),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reward() {
    final r = _own['reward'] as Map?;
    if (r == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (r['kind'] == 'embun') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GameIcon('bulirembun', size: 48),
          const SizedBox(width: 12),
          Text(
            '+${r['amount']} embun',
            style: const TextStyle(
              fontSize: 28,
              color: EmbunColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    final def = widget.defs[r['card_id']];
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: GameImage(path: cardArtPath(def), fit: BoxFit.contain),
        ),
        const SizedBox(height: 8),
        Text(
          '${r['name']}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, color: EmbunColors.gold),
        ),
      ],
    );
  }

  Widget _play() => KeyboardListener(
    focusNode: _focus,
    autofocus: true,
    onKeyEvent: (event) {
      final lane = _keys.indexOf(event.logicalKey);
      if (lane < 0) {
        return;
      }
      if (event is KeyDownEvent) {
        _down(lane);
      } else if (event is KeyUpEvent) {
        _up(lane);
      }
    },
    child: AnimatedBuilder(
      animation: _frames,
      builder: (_, _) {
        final t = _elapsed;
        final w = (math.max(0, t) ~/ melodyWaveMs)
            .clamp(0, (_duration - 1) ~/ melodyWaveMs)
            .toInt();
        final pressure =
            ((_state?['waves'] as List? ?? [])
                        .cast<Map>()
                        .where((x) => x['wave'] == w)
                        .firstOrNull?['pressure']
                    as num?)
                ?.toInt() ??
            0;
        _fx
          ..level = MelodyFxLevel.level.value
          ..reduced = MediaQuery.disableAnimationsOf(context)
          ..antag = widget.antagonist
          ..pressure = widget.antagonist ? 0 : pressure;
        return LayoutBuilder(
          builder: (context, box) {
            final short = box.maxHeight < 430;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: short ? 3 : 10,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'RITUAL MELODI',
                          style: TextStyle(
                            color: EmbunColors.gold,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Text(
                        '${((_duration - t).clamp(0, _duration) / 1000).ceil()} dtk',
                        style: const TextStyle(
                          color: EmbunColors.cream,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        tooltip: MelodyFxLevel.label(MelodyFxLevel.level.value),
                        onPressed: MelodyFxLevel.cycle,
                        icon: EmbunIcon(
                          MelodyFxLevel.level.value == 0
                              ? Icons.auto_awesome_outlined
                              : Icons.auto_awesome,
                          size: 24,
                          color: MelodyFxLevel.level.value == 0
                              ? Colors.white38
                              : (MelodyFxLevel.level.value == 1
                                    ? EmbunColors.cream
                                    : EmbunColors.gold),
                        ),
                      ),
                      IconButton(
                        tooltip: Sfx.I.muted.value
                            ? 'Nyalakan suara'
                            : 'Bisukan suara',
                        onPressed: () => Sfx.I.muted.value = !Sfx.I.muted.value,
                        icon: GameIcon(
                          Sfx.I.muted.value ? 'suaramati' : 'suaranyala',
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.antagonist
                      ? 'Kombo kelipatan 15 menguatkan gangguan irama.'
                      : pressure > 0
                      ? 'Bisikan mempercepat irama +${pressure * 5}%'
                      : 'Jaga ketepatan dan keselarasan ritual.',
                  style: TextStyle(
                    color: pressure > 0 ? EmbunColors.mist : Colors.white70,
                    fontSize: short ? 11 : 13,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Transform.translate(
                          offset: _fx.shakeOffset,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(painter: MelodyBackdropPainter(_fx)),
                              CustomPaint(
                                painter: MelodyLanePainter(
                                  notes: _judge.notes.toList(),
                                  judge: _judge,
                                  elapsed: t,
                                  fx: _fx,
                                  reduced: MediaQuery.disableAnimationsOf(
                                    context,
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: MelodyFrontPainter(_fx),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (t < 0)
                        Center(
                          child: MelodyCountdown(
                            number: (-t / 1000).ceil(),
                            color: widget.antagonist
                                ? EmbunColors.mist
                                : EmbunColors.gold,
                            reduced: MediaQuery.disableAnimationsOf(context),
                          ),
                        ),
                      if (t >= _duration)
                        const Center(
                          child: Text(
                            'Merangkum ritual…',
                            style: TextStyle(
                              color: EmbunColors.gold,
                              fontSize: 25,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        left: 12,
                        child: Text(
                          '${_judge.feedback}\nKombo ${_judge.combo} • terbaik ${_judge.maxCombo}',
                          style: const TextStyle(
                            color: EmbunColors.cream,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      for (var i = 0; i < 4; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Semantics(
                              label:
                                  '${_names[i]}, tombol ${['D', 'F', 'J', 'K'][i]}',
                              button: true,
                              child: Listener(
                                onPointerDown: (_) => _down(i),
                                onPointerUp: (_) => _up(i),
                                onPointerCancel: (_) => _up(i),
                                child: Container(
                                  height: short ? 58 : 82,
                                  decoration: BoxDecoration(
                                    color: _pressed.contains(i)
                                        ? _colors[i].withValues(alpha: .45)
                                        : const Color(0xFF14251E),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _colors[i],
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: short ? 25 : 34,
                                        child: GameImage(
                                          path: sceneryPath(_icons[i]),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Text(
                                        '${_names[i]} · ${['D', 'F', 'J', 'K'][i]}',
                                        style: const TextStyle(
                                          color: EmbunColors.cream,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_musicFailed && !Sfx.I.muted.value)
                  TextButton.icon(
                    onPressed: () {
                      _prepareAudio();
                      _music.retry();
                    },
                    icon: const EmbunIcon(Icons.volume_up),
                    label: const Text('Ketuk untuk mengaktifkan musik'),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            );
          },
        );
      },
    ),
  );
}

class _RitualAudioPort implements MelodyAudioPort {
  final AudioPlayer _player = AudioPlayer();
  @override
  Future<void> load(String asset) async {
    await _player.setReleaseMode(ReleaseMode.stop);
    // Decode a fully loaded asset instead of seeking a partially buffered
    // HTTP source. Web then uses a data URI through audioplayers, so cursor
    // changes do not depend on the host supporting HTTP byte-range requests.
    final data = await rootBundle.load('assets/$asset');
    await _player.setSource(
      BytesSource(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        mimeType: 'audio/mpeg',
      ),
    );
  }

  @override
  Future<void> rate(double value) => _player.setPlaybackRate(value);
  @override
  Future<void> volume(double value) => _player.setVolume(value);
  @override
  Future<void> seek(int milliseconds) =>
      _player.seek(Duration(milliseconds: milliseconds));
  @override
  Future<int?> position() async =>
      (await _player.getCurrentPosition())?.inMilliseconds;
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> dispose() => _player.dispose();
}

// Compatibility with a session created before the music migration.
class _LegacyRitualAudio {
  final Map<int, AudioPlayer> _players = {};
  bool _preparing = false, _disposed = false;
  int _key = -1;
  Future<void> prepare() async {
    if (_preparing || _players.isNotEmpty || _disposed) {
      return;
    }
    _preparing = true;
    for (var i = 0; i < 6; i++) {
      if (_disposed) {
        break;
      }
      final p = AudioPlayer();
      _players[i] = p;
      try {
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('sound/ritual-melody-$i.wav'));
      } catch (_) {}
    }
    _preparing = false;
    _key = -1;
  }

  void sync(int wave, int pressure, int elapsed, bool muted) {
    final key = wave * 10 + pressure;
    if (key == _key || !_players.containsKey(pressure)) {
      return;
    }
    _key = key;
    unawaited(() async {
      for (final p in _players.values.toList()) {
        try {
          await p.pause();
        } catch (_) {}
      }
      if (_disposed || muted || _key != key) {
        return;
      }
      final p = _players[pressure]!;
      try {
        await p.setVolume(.55);
        await p.seek(Duration(milliseconds: elapsed.clamp(0, 5999).toInt()));
        if (!_disposed && _key == key) {
          await p.resume();
        }
      } catch (_) {}
    }());
  }

  void mute(bool muted) {
    for (final p in _players.values.toList()) {
      unawaited(p.setVolume(muted ? 0 : .55).catchError((_) {}));
    }
    if (!muted) {
      _key = -1;
    }
  }

  void stop() {
    if (_key == -1) {
      return;
    }
    _key = -1;
    for (final p in _players.values.toList()) {
      unawaited(p.pause().catchError((_) {}));
    }
  }

  void dispose() {
    _disposed = true;
    for (final p in _players.values.toList()) {
      unawaited(p.dispose());
    }
    _players.clear();
  }
}

Future<void> showMelodyRewardPool(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Peluang hadiah ritual'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Satu hadiah utama. Nilai hadiah warga: 70% nilai pribadi + 30% rata-rata warga. Si Terbisik: nilai pribadi. Kartu selalu mengikuti peran; rinciannya hanya terlihat pemilik.',
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Nilai')),
                for (final x in melodyLabels) DataColumn(label: Text(x)),
              ],
              rows: [
                for (var i = 0; i < 7; i++)
                  DataRow(
                    cells: [
                      DataCell(Text(melodyBands[i])),
                      for (final n in melodyPools[i]) DataCell(Text('$n%')),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < 7; i++)
            Text(
              '${melodyBands[i]}: jika mendapat embun, ${melodyCoinRanges[i][0]}–${melodyCoinRanges[i][1]} embun.',
            ),
          const SizedBox(height: 10),
          const Text(
            'Kartu yang tidak tersedia pada katalog diganti embun pada tingkat nilai yang sama. Nilai memakai ketepatan dan kombo, bukan jumlah ketukan mentah.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Tutup'),
      ),
    ],
  ),
);
