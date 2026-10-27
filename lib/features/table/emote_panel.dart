import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../../data/errors.dart';
import '../common/art.dart';
import '../common/ornate.dart';

// Harus sama persis dengan daftar putih di fungsi send_emote (SQL).
const kEmotes = ['🙂', '😠', '🤔', '😰', '🙏', '👀', '🔥', '💧'];

// Harus sama dengan batas di send_emote (SQL).
const kEmoteLimit = 8;

/// Buka panel isyarat sebagai lembar bawah. Gantikan isi `_openEmotes` di
/// table_page.dart dengan satu panggilan ke fungsi ini.
///
/// Ponsel: selebar layar. Desktop/tablet: dipusatkan, lebar maksimum 560.
Future<void> showEmotePanel(
    BuildContext context, {
      required GameRepository repo,
      required String gameId,
      required int day,
      required List<Map<String, dynamic>> players,
    }) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return Container(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.94),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B2E2A), Color(0xFF0E1816)],
            ),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(
                color: EmbunColors.goldDim.withValues(alpha: 0.55),
                width: 1.2),
            boxShadow: [
              BoxShadow(
                color: EmbunColors.gold.withValues(alpha: 0.14),
                blurRadius: 26,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, 16 + mq.padding.bottom + mq.viewInsets.bottom),
                  child: EmotePanel(
                    repo: repo,
                    gameId: gameId,
                    day: day,
                    players: players,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

class EmotePanel extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final List<Map<String, dynamic>> players;

  const EmotePanel({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.players,
  });

  @override
  State<EmotePanel> createState() => _EmotePanelState();
}

class _EmotePanelState extends State<EmotePanel> {
  late final Stream<List<Map<String, dynamic>>> stream =
  widget.repo.emotes(widget.gameId);
  String? target;
  bool busy = false;

  String _name(String? id) {
    for (final p in widget.players) {
      if (p['user_id'] == id) return p['name'] as String;
    }
    return '?';
  }

  Future<void> _send(String emoji) async {
    HapticFeedback.selectionClick();
    setState(() => busy = true);
    try {
      await widget.repo.sendEmote(widget.gameId, emoji, target: target);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errMsg(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final others = widget.players
        .where((p) => p['user_id'] != widget.repo.myId)
        .toList();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, s) {
        final today =
        (s.data ?? []).where((e) => e['day'] == widget.day).toList();
        final mine =
            today.where((e) => e['user_id'] == widget.repo.myId).length;
        final left = (kEmoteLimit - mine).clamp(0, kEmoteLimit).toInt();
        final recent = today.reversed.take(8).toList();
        final empty = left <= 0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              icon: 'discuss',
              title: 'Isyarat',
              iconSize: 28,
              trailing: _Quota(left: left),
            ),
            const SizedBox(height: 12),
            _feed(recent),
            const SizedBox(height: 14),
            const Text('Kirim ke',
                style: TextStyle(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 6),
            _targets(others),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in kEmotes)
                  _EmoteButton(
                    emoji: e,
                    enabled: !busy && !empty,
                    dimmed: empty,
                    onTap: () => _send(e),
                  ),
              ],
            ),
            if (empty) ...[
              const SizedBox(height: 10),
              const Text(
                'Batas isyarat hari ini sudah habis.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Riwayat isyarat hari ini, yang terbaru di kiri.
  Widget _feed(List<Map<String, dynamic>> recent) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.25)),
      ),
      child: recent.isEmpty
          ? const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text('Belum ada isyarat hari ini',
              style: TextStyle(fontSize: 12, color: Colors.white54)),
        ),
      )
          : ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recent.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final e = recent[i];
          final tgt = e['target_id'] as String?;
          final text = '${_name(e['user_id'] as String?)} ${e['emoji']}'
              '${tgt == null ? '' : ' → ${_name(tgt)}'}';
          return Center(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(text, style: const TextStyle(fontSize: 13)),
            ),
          );
        },
      ),
    );
  }

  /// Pilih sasaran: semua orang atau satu pemain (dengan potretnya).
  Widget _targets(List<Map<String, dynamic>> others) {
    ChoiceChip chip({
      required Widget avatar,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) =>
        ChoiceChip(
          avatar: avatar,
          label: Text(label, overflow: TextOverflow.ellipsis),
          selected: selected,
          showCheckmark: false,
          selectedColor: EmbunColors.gold.withValues(alpha: 0.28),
          side: BorderSide(
            color: selected
                ? EmbunColors.gold
                : EmbunColors.goldDim.withValues(alpha: 0.35),
          ),
          onSelected: (_) {
            HapticFeedback.selectionClick();
            onTap();
          },
        );

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: chip(
              avatar: const Icon(Icons.groups_rounded,
                  size: 20, color: EmbunColors.gold),
              label: 'Semua',
              selected: target == null,
              onTap: () => setState(() => target = null),
            ),
          ),
          for (final p in others)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: chip(
                avatar: PlayerAvatar(
                  path: protagonistPath(p['character_card'] as String),
                  size: 24,
                  ring: target == p['user_id']
                      ? EmbunColors.gold
                      : EmbunColors.goldDim,
                ),
                label: p['name'] as String,
                selected: target == p['user_id'],
                onTap: () => setState(() => target = p['user_id'] as String),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sisa isyarat sebagai deretan titik: terisi = masih ada, kosong = terpakai.
class _Quota extends StatelessWidget {
  final int left;
  const _Quota({required this.left});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sisa $left isyarat',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < kEmoteLimit; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < left ? EmbunColors.gold : Colors.transparent,
              border: Border.all(
                color: i < left ? EmbunColors.gold : Colors.white30,
              ),
            ),
          ),
        const SizedBox(width: 8),
        Text('Sisa $left',
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    ),
  );
}

/// Satu isyarat: ubin 56x56 yang menekan saat disentuh.
class _EmoteButton extends StatefulWidget {
  final String emoji;
  final bool enabled;
  final bool dimmed;
  final VoidCallback onTap;
  const _EmoteButton({
    required this.emoji,
    required this.enabled,
    required this.dimmed,
    required this.onTap,
  });

  @override
  State<_EmoteButton> createState() => _EmoteButtonState();
}

class _EmoteButtonState extends State<_EmoteButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: widget.dimmed ? 0.35 : 1,
    child: AnimatedScale(
      scale: _down ? 0.88 : 1,
      duration: const Duration(milliseconds: 120),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.enabled ? widget.onTap : null,
          onHighlightChanged: (v) => setState(() => _down = v),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
        ),
      ),
    ),
  );
}