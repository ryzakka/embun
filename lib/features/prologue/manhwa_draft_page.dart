import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import '../lobby/lobby_page.dart';
import 'prologue_page.dart';

class ManhwaDraftPage extends StatefulWidget {
  const ManhwaDraftPage({super.key, required this.repo, required this.gameId});
  final LobbyRepository repo;
  final String gameId;
  @override
  State<ManhwaDraftPage> createState() => _ManhwaDraftPageState();
}

class _ManhwaDraftPageState extends State<ManhwaDraftPage> {
  Map<String, dynamic>? _state;
  String? _selected, _error;
  bool _busy = false,
      _loading = false,
      _navigated = false,
      _wasDrafting = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _accept(Map<String, dynamic> state) {
    if (!mounted) return;
    final characters = state['stage'] == 'characters';
    final items = (state[characters ? 'characters' : 'outfits'] as List? ?? [])
        .cast<Map>();
    final canKeepSelection =
        state['status'] == 'prologue' &&
        _state?['stage'] == state['stage'] &&
        (characters
            ? state['turn'] == widget.repo.myId
            : (state['own'] as Map?)?['outfit_card'] == null) &&
        items.any((item) => item['id'] == _selected && item['taken'] != true);
    setState(() {
      _state = state;
      if (!canKeepSelection) _selected = null;
      _error = null;
    });
    if (state['status'] == 'prologue') _wasDrafting = true;
    if (_navigated) return;
    if (state['status'] == 'playing' || state['status'] == 'finished') {
      _navigated = true;
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Sfx.I.stopMenuMusic();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => state['status'] == 'playing'
                ? PrologueFlow(
                    gameId: widget.gameId,
                    repo: widget.repo,
                    characterTheme: 'manhwa',
                    resume: !_wasDrafting,
                    antagonistCount: (state['antagonist_count'] as int?) ?? 1,
                  )
                : const LobbyPage(startAtMenu: true),
          ),
        );
      });
    }
  }

  Future<void> _load() async {
    if (_loading || _busy || _navigated) return;
    _loading = true;
    try {
      _accept(await widget.repo.manhwaDraft(widget.gameId));
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      _loading = false;
    }
  }

  Future<void> _confirm() async {
    if (_busy || _selected == null) return;
    final selected = _selected!;
    setState(() => _busy = true);
    try {
      final state = _state!['stage'] == 'characters'
          ? await widget.repo.chooseManhwaCharacter(widget.gameId, selected)
          : await widget.repo.chooseManhwaOutfit(widget.gameId, selected);
      _accept(state);
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelRoom() async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bubarkan ruangan?'),
        content: const Text(
          'Pemilihan tokoh akan dihentikan untuk semua pemain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bubarkan'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repo.endGame(widget.gameId);
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final stage = s?['stage'];
    final own = s?['own'] as Map?;
    final mine = stage == 'characters'
        ? (s?['turn'] == widget.repo.myId)
        : (stage == 'outfits' && (own?['outfit_card'] == null));
    final players = (s?['players'] as List? ?? []).cast<Map>();
    final turnName =
        players.where((p) => p['user_id'] == s?['turn']).firstOrNull?['name'] ??
        'pemain berikutnya';
    final characters = stage == 'characters';
    final items = (s?[characters ? 'characters' : 'outfits'] as List? ?? [])
        .cast<Map>();
    final locked = stage == 'outfits' && (own?['outfit_card'] != null);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF171522),
        appBar: AppBar(
          title: const Text('Manhwa Style'),
          automaticallyImplyLeading: false,
          actions: [
            if (s?['host_id'] == widget.repo.myId)
              IconButton(
                tooltip: 'Bubarkan ruangan',
                onPressed: _busy ? null : _cancelRoom,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        body: SafeArea(
          child: s == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Coba lagi'),
                            ),
                          ],
                        ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            characters
                                ? (mine
                                      ? 'Giliranmu memilih tokoh'
                                      : 'Menunggu $turnName memilih tokoh')
                                : locked
                                ? 'Pakaianmu sudah terkunci'
                                : 'Pilih pakaian tokohmu',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: EmbunColors.gold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            characters
                                ? 'Setiap tokoh hanya bisa dipilih satu pemain. Urutan mengikuti pemain masuk ruangan.'
                                : 'Setelah semua pakaian terkunci, peran dibagikan dan pengungkapan dimulai.',
                            textAlign: TextAlign.center,
                          ),
                          if (s['seconds_left'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Sisa waktu ${s['seconds_left']} detik',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ExpansionTile(
                            title: const Text('Pilihan semua pemain'),
                            children: [
                              for (final p in players)
                                ListTile(
                                  dense: true,
                                  title: Text('${p['name']}'),
                                  subtitle: Text(
                                    manhwaNames[p['character_id']] ??
                                        'Belum memilih tokoh',
                                  ),
                                  trailing: p['outfit_card'] != null
                                      ? const Icon(Icons.check_circle_outline)
                                      : null,
                                ),
                            ],
                          ),
                          if (_error != null) ...[
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                              ),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _load,
                              child: const Text('Muat ulang pilihan'),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (locked)
                            Center(
                              child: Column(
                                children: [
                                  CardArt(
                                    path: protagonistPath(
                                      '${own!['outfit_card']}',
                                    ),
                                    width: 180,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Menunggu pemain lain…'),
                                ],
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, c) {
                                final cols = (c.maxWidth / 155).floor().clamp(
                                  2,
                                  6,
                                );
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: items.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: cols,
                                        childAspectRatio: 0.52,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 14,
                                      ),
                                  itemBuilder: (context, i) {
                                    final item = items[i];
                                    final taken =
                                        characters && item['taken'] == true;
                                    final id = '${item['id']}';
                                    final path = protagonistPath(
                                      '${characters ? item['preview'] : id}',
                                    );
                                    return InkWell(
                                      key: ValueKey('manhwa-$id'),
                                      onTap: !mine || taken || _busy
                                          ? null
                                          : () =>
                                                setState(() => _selected = id),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Opacity(
                                        opacity: taken ? 0.35 : 1,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: _selected == id
                                                  ? EmbunColors.gold
                                                  : Colors.transparent,
                                              width: 3,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: LayoutBuilder(
                                              builder: (ctx, b) => Column(
                                                children: [
                                                  CardArt(
                                                    path: path,
                                                    width: b.maxWidth,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Expanded(
                                                    child: Center(
                                                      child: Text(
                                                        '${characters ? item['name'] : item['label']}${taken ? ' · Terpilih' : ''}',
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 3,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          if (mine && !locked) ...[
                            const SizedBox(height: 16),
                            EmbunButton(
                              label: _busy
                                  ? 'Mengunci…'
                                  : characters
                                  ? 'Kunci tokoh'
                                  : 'Kunci pakaian',
                              icon: 'lock',
                              onPressed: _selected == null || _busy
                                  ? null
                                  : _confirm,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
