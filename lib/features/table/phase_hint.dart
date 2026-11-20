import 'package:flutter/material.dart';
import '../common/ornate.dart';

/// Petunjuk ringkas. Rincian di lembar terpisah menjaga ruang aksi layar kecil.
class PhaseHint extends StatefulWidget {
  const PhaseHint({
    super.key,
    required this.title,
    required this.details,
    this.icon = Icons.info_outline,
    this.accent = EmbunColors.gold,
  });

  final String title;
  final List<String> details;
  final IconData icon;
  final Color accent;

  @override
  State<PhaseHint> createState() => _PhaseHintState();
}

class _PhaseHintState extends State<PhaseHint> {
  ModalRoute<dynamic>? _sheet;
  bool _opening = false;
  String get title => widget.title;
  List<String> get details => widget.details;
  IconData get icon => widget.icon;
  Color get accent => widget.accent;

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          _sheet = ModalRoute.of(sheetContext);
          return _details(sheetContext);
        },
      );
    } finally {
      _sheet = null;
      _opening = false;
    }
  }

  @override
  void dispose() {
    // Lembar petunjuk tidak boleh tertinggal menutupi fase berikutnya.
    final sheet = _sheet;
    if (sheet != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sheet.isActive) sheet.navigator?.removeRoute(sheet);
      });
    }
    super.dispose();
  }

  Widget _details(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .65,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontSize: 16, color: accent,
                fontWeight: FontWeight.w700)),
            for (final detail in details)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(detail,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .28),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _open,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 16),
            const SizedBox(width: 7),
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 12, color: accent)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, color: accent, size: 18),
          ],
        ),
      ),
    ),
  );
}
