import 'package:flutter/material.dart';

import '../../data/game_rules.dart';
import '../common/art.dart';
import '../common/ornate.dart';

BorderSide roomEntryRule([Color color = EmbunColors.gold]) =>
    BorderSide(color: color.withValues(alpha: 0.30));

class RoomEntryFrame extends StatelessWidget {
  final Widget child;
  const RoomEntryFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xD3071510), Color(0x8107130F), Color(0xF007130F)],
        stops: [0, 0.46, 1],
      ),
    ),
    child: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: LayoutBuilder(
            builder: (context, box) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: box.maxWidth < 450 ? 12 : 24,
              ),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

class RoomEntryHeader extends StatelessWidget {
  final String title;
  final String icon;
  final VoidCallback? onBack;
  final Widget? action;

  const RoomEntryHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.onBack,
    this.action,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            icon: const GameIcon('back', size: 23),
            onPressed: onBack,
          ),
          if (box.maxWidth >= 320) ...[
            GameIcon(icon, size: 28),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: EmbunColors.cream,
                ),
              ),
            ),
          ),
          ?action,
        ],
      ),
    ),
  );
}

class CreateRoomView extends StatefulWidget {
  final TextEditingController nameCtrl;
  final bool isPublic;
  final int cycles;
  final int antagonistCount;
  final bool busy;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onAntagonistCountChanged;
  final ValueChanged<String> onCreate;
  final VoidCallback onBack;

  const CreateRoomView({
    super.key,
    required this.nameCtrl,
    required this.isPublic,
    required this.cycles,
    required this.antagonistCount,
    required this.busy,
    required this.onVisibilityChanged,
    required this.onDurationChanged,
    required this.onAntagonistCountChanged,
    required this.onCreate,
    required this.onBack,
  });

  @override
  State<CreateRoomView> createState() => _CreateRoomViewState();
}

class _CreateRoomViewState extends State<CreateRoomView> {
  static const _targets = {2: 12, 4: 20, 6: 24, 8: 26};
  final _nameFocus = FocusNode();
  bool _nameMissing = false;

  int get _days => widget.cycles * kCycleDays;
  int get _target => _targets[widget.cycles]!;
  String get _access => widget.isPublic
      ? 'Pemain bisa menemukan ruanganmu di daftar publik.'
      : 'Pemain bisa masuk dengan kode yang kamu bagikan.';

  @override
  void dispose() {
    _nameFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.busy) return;
    final name = widget.nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      _nameFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onCreate(name);
  }

  @override
  Widget build(BuildContext context) => RoomEntryFrame(
    child: LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 710;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Visibility(
              visible: box.maxHeight >= 180,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: roomEntryRule()),
                ),
                child: RoomEntryHeader(
                  title: 'Buat Ruangan',
                  icon: 'roomcreate',
                  onBack: widget.busy ? null : widget.onBack,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  vertical: box.maxHeight < 450 ? 12 : 20,
                ),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _form(showTarget: false)),
                          const SizedBox(width: 38),
                          Expanded(flex: 2, child: _summary()),
                        ],
                      )
                    : _form(showTarget: true),
              ),
            ),
            Visibility(
              visible: box.maxHeight >= 115,
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border(top: roomEntryRule())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: wide ? 264 : double.infinity,
                      child: EmbunButton(
                        label: widget.busy
                            ? 'Membuat ruangan…'
                            : 'Buat Ruangan',
                        icon: widget.busy ? 'wait' : 'roomcreate',
                        expand: true,
                        height: 45,
                        onPressed: widget.busy ? null : _submit,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _form({required bool showTarget}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: widget.nameCtrl,
        focusNode: _nameFocus,
        enabled: !widget.busy,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.words,
        maxLength: 20,
        onSubmitted: (_) => _submit(),
        onChanged: (_) {
          if (_nameMissing) setState(() => _nameMissing = false);
        },
        decoration: InputDecoration(
          labelText: 'Namamu',
          counterText: '',
          errorText: _nameMissing ? 'Isi namamu dulu' : null,
          prefixIcon: const Padding(
            padding: EdgeInsets.all(8),
            child: GameIcon('identity', size: 24),
          ),
        ),
      ),
      const SizedBox(height: 18),
      _label('Akses ruangan'),
      const SizedBox(height: 5),
      DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: roomEntryRule())),
        child: Row(
          children: [
            Expanded(
              child: _visibilityChoice(
                false,
                'Privat',
                'lock',
              ),
            ),
            Expanded(
              child: _visibilityChoice(true, 'Publik', 'persona'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 7),
      Text(
        _access,
        style: const TextStyle(
          fontSize: 13,
          height: 1.35,
          color: Colors.white70,
        ),
      ),
      const SizedBox(height: 18),
      _label('Lama permainan'),
      const SizedBox(height: 5),
      Wrap(
        spacing: 7,
        runSpacing: 3,
        children: [
          for (final cycles in _targets.keys)
            ChoiceChip(
              label: Text(
                '${cycles * kCycleDays} hari',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              showCheckmark: false,
              tooltip: cycles == 4 ? 'Durasi bawaan' : null,
              selected: widget.cycles == cycles,
              selectedColor: EmbunColors.leaf.withValues(alpha: 0.26),
              side: roomEntryRule(
                widget.cycles == cycles ? EmbunColors.gold : Colors.white70,
              ),
              onSelected: widget.busy
                  ? null
                  : (_) => widget.onDurationChanged(cycles),
            ),
        ],
      ),
      const SizedBox(height: 18),
      _label('Jumlah antagonis'),
      const SizedBox(height: 5),
      Wrap(
        spacing: 7,
        runSpacing: 3,
        children: [
          for (final count in [1, 2])
            ChoiceChip(
              label: Text(antagonistModeLabel(count)),
              showCheckmark: false,
              selected: widget.antagonistCount == count,
              selectedColor: EmbunColors.mist.withValues(alpha: 0.22),
              side: roomEntryRule(
                widget.antagonistCount == count
                    ? EmbunColors.mist
                    : Colors.white70,
              ),
              onSelected: widget.busy
                  ? null
                  : (_) => widget.onAntagonistCountChanged(count),
            ),
        ],
      ),
      if (widget.antagonistCount == 2)
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Text(
            'Mulai setelah minimal $kMinDuaTerbisikPlayers pemain siap.',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ),
      if (showTarget) ...[const SizedBox(height: 10), _targetNote()],
    ],
  );

  Widget _visibilityChoice(bool value, String label, String icon) {
    final selected = widget.isPublic == value;
    final color = selected ? EmbunColors.gold : EmbunColors.cream;
    return Semantics(
      selected: selected,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: selected
              ? EmbunColors.leaf.withValues(alpha: 0.15)
              : null,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: widget.busy ? null : () => widget.onVisibilityChanged(value),
        icon: GameIcon(icon, size: 19),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _summary() => DecoratedBox(
    decoration: BoxDecoration(border: Border(left: roomEntryRule())),
    child: Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GameIcon(widget.isPublic ? 'persona' : 'roomcode', size: 44),
          const SizedBox(height: 10),
          _label(
            widget.isPublic ? 'Ruangan publik' : 'Ruangan privat',
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            '$_days hari${widget.cycles == 4 ? ' (bawaan)' : ''} · '
            '${minPlayersFor(widget.antagonistCount)}–$kMaxPlayers pemain',
            style: const TextStyle(
              color: EmbunColors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _targetNote(),
        ],
      ),
    ),
  );

  Widget _targetNote() => Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'Warga menang dengan minimal '),
        TextSpan(
          text: '$_target daun',
          style: const TextStyle(
            color: EmbunColors.leaf,
            fontWeight: FontWeight.w800,
          ),
        ),
        TextSpan(
          text:
              ' di akhir hari ke-$_days, atau dengan $kLeavesMax daun lebih cepat.',
        ),
      ],
    ),
    style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.white70),
  );

  Widget _label(String title, {double size = 15}) => Semantics(
    header: true,
    child: Text(
      title,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: EmbunColors.cream,
      ),
    ),
  );
}
