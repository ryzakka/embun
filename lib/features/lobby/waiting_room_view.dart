import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_rules.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'room_entry_view.dart';

class WaitingRoomView extends StatefulWidget {
  final String code;
  final String characterTheme;
  final bool isPublic;
  final int antagonistCount;
  final String hostId;
  final String? viewerId;
  final List<Map<String, dynamic>> players;
  final Stream<List<Map<String, dynamic>>> chatMessages;
  final Widget chat;
  final Future<void> Function(bool) onVisibilityChanged;
  final Future<void> Function(bool) onReady;
  final Future<void> Function() onStart;
  final Future<void> Function() onLeave;
  final Future<void> Function(Map<String, dynamic>) onEditCharacter;

  const WaitingRoomView({
    super.key,
    required this.code,
    this.characterTheme = 'default',
    required this.isPublic,
    required this.antagonistCount,
    required this.hostId,
    required this.viewerId,
    required this.players,
    required this.chatMessages,
    required this.chat,
    required this.onVisibilityChanged,
    required this.onReady,
    required this.onStart,
    required this.onLeave,
    required this.onEditCharacter,
  });

  @override
  State<WaitingRoomView> createState() => _WaitingRoomViewState();
}

class _WaitingRoomViewState extends State<WaitingRoomView> {
  final _pages = PageController();
  int _page = 0;
  int _seen = 0;
  bool _busy = false;

  bool get _host => widget.viewerId == widget.hostId;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _toast(errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.code));
      if (mounted) _toast('Kode disalin');
    } catch (_) {
      if (mounted) _toast('Kode tidak bisa disalin. Kamu bisa mencatatnya.');
    }
  }

  @override
  Widget build(BuildContext context) => RoomEntryFrame(
    child: LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 820;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (box.maxHeight >= 230) _header(inline: box.maxWidth >= 510),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _room()),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 310,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(left: roomEntryRule()),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 18),
                              child: _chatPane(title: true),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _phone(showTabs: box.maxHeight >= 155),
            ),
          ],
        );
      },
    ),
  );

  Widget _header({required bool inline}) {
    final invitation = Row(
      mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (inline) ...[
          const GameIcon('roomcode', size: 35),
          const SizedBox(width: 9),
        ],
        Flexible(
          fit: inline ? FlexFit.loose : FlexFit.tight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RUANG TUNGGU',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.code,
                  semanticsLabel: 'Kode undangan ${widget.code}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: EmbunColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _copy,
          icon: const GameIcon('salin', size: 19),
          label: const Text('Salin'),
        ),
      ],
    );
    final access = Row(
      mainAxisAlignment: inline
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        GameIcon(widget.isPublic ? 'persona' : 'lock', size: 18),
        const SizedBox(width: 6),
        Flexible(
          fit: inline ? FlexFit.loose : FlexFit.tight,
          child: Text(
            widget.isPublic
                ? 'Publik · tampil di daftar'
                : 'Privat · lewat kode',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
        if (_host)
          Semantics(
            label: 'Ruangan publik',
            child: Switch(
              value: widget.isPublic,
              onChanged: _busy
                  ? null
                  : (value) => _act(() => widget.onVisibilityChanged(value)),
            ),
          ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: roomEntryRule())),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: inline
            ? Row(
                children: [
                  Expanded(flex: 3, child: invitation),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: access),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [invitation, access],
              ),
      ),
    );
  }

  Widget _phone({required bool showTabs}) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.chatMessages,
        builder: (context, snapshot) {
          final count = snapshot.data
              ?.where((m) => m['user_id'] != widget.viewerId)
              .length;
          if (_page == 1 && count != null) _seen = count;
          final unread = math.max(0, (count ?? _seen) - _seen);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTabs)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(bottom: roomEntryRule()),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _tab('Pemain', 0)),
                      Expanded(
                        child: _tab(
                          unread > 0 ? 'Obrolan ($unread)' : 'Obrolan',
                          1,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: PageView(
                  key: PageStorageKey('waiting-room-tabs-${widget.code}'),
                  controller: _pages,
                  onPageChanged: (page) => setState(() {
                    _page = page;
                    if (page == 1 && count != null) _seen = count;
                  }),
                  children: [
                    _room(),
                    _KeepRoomPane(child: _chatPane()),
                  ],
                ),
              ),
            ],
          );
        },
      );

  Widget _tab(String label, int page) {
    final selected = page == _page;
    return Semantics(
      selected: selected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: selected ? EmbunColors.gold : Colors.transparent,
            ),
          ),
        ),
        child: TextButton(
          onPressed: () => _pages.animateToPage(
            page,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? EmbunColors.gold : EmbunColors.cream,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chatPane({bool title = false}) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      primary: false,
      physics: box.maxHeight < 126
          ? null
          : const NeverScrollableScrollPhysics(),
      child: SizedBox(
        height: math.max(box.maxHeight, 126),
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title)
                const Text(
                  'Obrolan Desa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: EmbunColors.cream,
                  ),
                ),
              Expanded(child: widget.chat),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _room() {
    final count = widget.players.length;
    final ready = widget.players.where((p) => p['ready'] == true).length;
    final available = widget.players.any(
      (p) => p['user_id'] == widget.viewerId,
    );
    final viewerReady = widget.players.any(
      (p) => p['user_id'] == widget.viewerId && p['ready'] == true,
    );
    final missing = minPlayersFor(widget.antagonistCount) - count;
    final canStart = missing <= 0 && ready == count;
    final message = !available
        ? 'Memuat data pemain…'
        : missing > 0
        ? 'Menunggu $missing pemain lagi.'
        : !canStart
        ? 'Menunggu ${count - ready} pemain siap.'
        : _host
        ? 'Semua siap. Permainan bisa dimulai.'
        : 'Semua siap. Menunggu host memulai.';
    final roster = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 7),
        child: Wrap(
          spacing: 14,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$count/$kMaxPlayers pemain',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: EmbunColors.cream,
              ),
            ),
            Text(
              widget.characterTheme == 'manhwa'
                  ? 'Tema: Manhwa Style · tokoh dipilih bergiliran'
                  : 'Tema: Default',
              style: const TextStyle(color: Colors.white70),
            ),
            if (widget.antagonistCount == 2)
              Text(
                antagonistModeLabel(widget.antagonistCount),
                style: const TextStyle(
                  color: EmbunColors.mist,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              '$ready siap',
              style: const TextStyle(
                color: EmbunColors.leaf,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      LinearProgressIndicator(
        value: count == 0 ? 0 : ready / count,
        minHeight: 2,
        color: EmbunColors.leaf,
        backgroundColor: Colors.white12,
        semanticsLabel: '$ready dari $count pemain siap',
      ),
      for (final player in widget.players) _player(player),
      if (count < kMaxPlayers)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const GameIcon('addmember', size: 21),
              const SizedBox(width: 6),
              Text(
                '${kMaxPlayers - count} slot kosong',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
    ];
    final actions = _actions(message, available, viewerReady, canStart);
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxHeight < 210) {
          return ListView(
            primary: false,
            padding: EdgeInsets.zero,
            children: [actions, ...roster],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                primary: false,
                padding: EdgeInsets.zero,
                children: roster,
              ),
            ),
            actions,
          ],
        );
      },
    );
  }

  Widget _player(Map<String, dynamic> player) {
    final id = player['user_id'] as String;
    final ready = player['ready'] == true;
    final card = (player['character_card'] as String?) ?? 'default';
    final viewer = id == widget.viewerId;
    final tags = [if (id == widget.hostId) 'Host', if (viewer) 'Kamu'];
    return DecoratedBox(
      key: ValueKey(id),
      decoration: BoxDecoration(border: Border(bottom: roomEntryRule())),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            PlayerAvatar(
              path: protagonistPath(card),
              size: 38,
              ring: viewer
                  ? EmbunColors.gold
                  : ready
                  ? EmbunColors.leaf
                  : Colors.white38,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player['name'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.cream,
                    ),
                  ),
                  Text(
                    [characterTitle(card), ...tags].join(' · '),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              ready ? 'Siap' : 'Belum siap',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ready ? EmbunColors.leaf : Colors.white70,
              ),
            ),
            if (viewer)
              IconButton(
                tooltip: widget.characterTheme == 'manhwa'
                    ? 'Tokoh dipilih setelah Mulai'
                    : ready
                    ? 'Karakter terkunci selama siap'
                    : 'Ganti karakter',
                icon: GameIcon(ready ? 'lock' : 'change', size: 21),
                color: EmbunColors.gold,
                onPressed: _busy || ready || widget.characterTheme == 'manhwa'
                    ? null
                    : () => _act(() => widget.onEditCharacter(player)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actions(String message, bool available, bool ready, bool canStart) {
    final controls = <Widget>[
      Expanded(
        child: EmbunButton(
          label: ready ? 'Batal siap' : 'Siap',
          height: 44,
          expand: true,
          kind: ready ? EmbunButtonKind.secondary : EmbunButtonKind.primary,
          onPressed: _busy || !available
              ? null
              : () => _act(() => widget.onReady(!ready)),
        ),
      ),
      if (_host) ...[
        const SizedBox(width: 8),
        Expanded(
          child: EmbunButton(
            label: 'Mulai',
            height: 44,
            expand: true,
            onPressed: _busy || !available || !canStart
                ? null
                : () => _act(widget.onStart),
          ),
        ),
      ],
    ];
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: roomEntryRule())),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: _busy ? null : () => _act(widget.onLeave),
                  icon: GameIcon(_host ? 'bubarkan' : 'keluar', size: 19),
                  label: Text(_host ? 'Bubarkan' : 'Keluar'),
                ),
              ],
            ),
            Row(children: controls),
          ],
        ),
      ),
    );
  }
}

class _KeepRoomPane extends StatefulWidget {
  final Widget child;
  const _KeepRoomPane({required this.child});

  @override
  State<_KeepRoomPane> createState() => _KeepRoomPaneState();
}

class _KeepRoomPaneState extends State<_KeepRoomPane>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
